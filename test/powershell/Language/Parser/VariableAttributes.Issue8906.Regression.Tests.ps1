# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe "Issue #8906 regression coverage for current behavior" -Tags "CI" {
    It "Set-Variable -Option ReadOnly still enforces write protection" {
        $name = "issue8906_reg_readonly_1"

        try {
            New-Variable -Name $name -Value 10 -Option ReadOnly

            (Get-Variable -Name $name).Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)

            $err = $null
            Set-Variable -Name $name -Value 11 -ErrorAction SilentlyContinue -ErrorVariable err
            $err.FullyQualifiedErrorId | Should -Match "^VariableNotWritable"
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }

    It "Set-Variable -Option Constant still enforces write protection" {
        $name = "issue8906_reg_constant_1"

        try {
            New-Variable -Name $name -Value 20 -Option Constant

            (Get-Variable -Name $name).Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::Constant)

            $err = $null
            Set-Variable -Name $name -Value 21 -ErrorAction SilentlyContinue -ErrorVariable err
            $err.FullyQualifiedErrorId | Should -Match "^VariableNotWritable"
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }

    It "Set-Variable -Force updates a read-only variable without changing its option" {
        $name = "issue8906_reg_readonly_force"

        try {
            New-Variable -Name $name -Value 10 -Option ReadOnly

            Set-Variable -Name $name -Value 11 -Force

            $variable = Get-Variable -Name $name
            $variable.Value | Should -Be 11
            $variable.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }

    It "Clear-Variable follows the existing read-only and constant force rules" {
        $readOnlyName = "issue8906_reg_readonly_clear"
        $constantName = "issue8906_reg_constant_clear"

        $result = & {
            New-Variable -Name $readOnlyName -Value 20 -Option ReadOnly
            New-Variable -Name $constantName -Value 30 -Option Constant

            $readOnlyError = $null
            Clear-Variable -Name $readOnlyName -ErrorAction SilentlyContinue -ErrorVariable readOnlyError
            $readOnlyValueBeforeForce = Get-Variable -Name $readOnlyName -ValueOnly
            Clear-Variable -Name $readOnlyName -Force

            $constantError = $null
            Clear-Variable -Name $constantName -Force -ErrorAction SilentlyContinue -ErrorVariable constantError

            [pscustomobject]@{
                ReadOnlyErrorId = $readOnlyError.FullyQualifiedErrorId
                ReadOnlyValueBeforeForce = $readOnlyValueBeforeForce
                ReadOnlyValueAfterForce = Get-Variable -Name $readOnlyName -ValueOnly
                ReadOnlyOptions = (Get-Variable -Name $readOnlyName).Options
                ConstantErrorId = $constantError.FullyQualifiedErrorId
                ConstantValue = Get-Variable -Name $constantName -ValueOnly
                ConstantOptions = (Get-Variable -Name $constantName).Options
            }
        }

        $result.ReadOnlyErrorId | Should -Be "VariableNotWritable,Microsoft.PowerShell.Commands.ClearVariableCommand"
        $result.ReadOnlyValueBeforeForce | Should -Be 20
        $result.ReadOnlyValueAfterForce | Should -BeNullOrEmpty
        $result.ReadOnlyOptions | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        $result.ConstantErrorId | Should -Be "VariableNotWritable,Microsoft.PowerShell.Commands.ClearVariableCommand"
        $result.ConstantValue | Should -Be 30
        $result.ConstantOptions | Should -Be ([System.Management.Automation.ScopedItemOptions]::Constant)
    }

    It "PSVariable accepts combined read-only and constant option flags" {
        $name = "issue8906_reg_combined_options"
        $options = [System.Management.Automation.ScopedItemOptions]::ReadOnly -bor
            [System.Management.Automation.ScopedItemOptions]::Constant

        $result = & {
            New-Variable -Name $name -Value 40 -Option $options
            $variable = Get-Variable -Name $name

            [pscustomobject]@{
                Value = $variable.Value
                Options = $variable.Options
            }
        }

        $result.Value | Should -Be 40
        $result.Options | Should -Be $options
    }

    It "System.ComponentModel.ReadOnlyAttribute remains resolvable for variables" {
        $result = & ([ScriptBlock]::Create(@'
using namespace System.ComponentModel

[ReadOnly($true)]$value = 50
$variable = Get-Variable -Name value

[pscustomobject]@{
    Value = $variable.Value
    AttributeType = $variable.Attributes[0].GetType().FullName
}
'@))

        $result.Value | Should -Be 50
        $result.AttributeType | Should -Be "System.ComponentModel.ReadOnlyAttribute"
    }

    It "Trying to make an existing variable constant still fails" {
        $name = "issue8906_reg_existing_1"

        try {
            Set-Variable -Name $name -Value 1

            $variable = Get-Variable -Name $name
            { $variable.Options = [System.Management.Automation.ScopedItemOptions]::Constant } |
                Should -Throw -ErrorId "ExceptionWhenSetting"
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }

    It "ValidateRange attribute on variable assignment continues to enforce validation" {
        $result = & {
            [ValidateRange(1,5)]$value = 3
            $errorId = $null
            try {
                Set-Variable -Name value -Value 9 -ErrorAction Stop
            }
            catch {
                $errorId = $_.FullyQualifiedErrorId
            }

            [pscustomobject]@{
                ErrorId = $errorId
                Value = $value
            }
        }

        $result.ErrorId | Should -Match "^ValidateSetFailure"
        $result.Value | Should -Be 3
    }

    It "ValidateNotNull attribute on variable assignment continues to enforce validation" {
        $result = & {
            [ValidateNotNull()]$value = 'ok'
            $errorId = $null
            try {
                Set-Variable -Name value -Value $null -ErrorAction Stop
            }
            catch {
                $errorId = $_.FullyQualifiedErrorId
            }

            [pscustomobject]@{
                ErrorId = $errorId
                Value = $value
            }
        }

        $result.ErrorId | Should -Match "^ValidateSetFailure"
        $result.Value | Should -Be "ok"
    }
}
