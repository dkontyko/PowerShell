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
        $name = "issue8906_reg_validateRange_1"

        try {
            & ([ScriptBlock]::Create("[ValidateRange(1,5)]`$script:$name = 3"))

            (Get-Variable -Name $name -ValueOnly) | Should -Be 3

            $errorId = $null
            try {
                Set-Variable -Name $name -Scope Script -Value 9 -ErrorAction Stop
            }
            catch {
                $errorId = $_.FullyQualifiedErrorId
            }

            $errorId | Should -Match "^ValidateSetFailure"

            (Get-Variable -Name $name -ValueOnly) | Should -Be 3
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }

    It "ValidateNotNull attribute on variable assignment continues to enforce validation" {
        $name = "issue8906_reg_validateNotNull_1"

        try {
            & ([ScriptBlock]::Create("[ValidateNotNull()]`$script:$name = 'ok'"))

            (Get-Variable -Name $name -ValueOnly) | Should -Be "ok"

            $errorId = $null
            try {
                Set-Variable -Name $name -Scope Script -Value $null -ErrorAction Stop
            }
            catch {
                $errorId = $_.FullyQualifiedErrorId
            }

            $errorId | Should -Match "^ValidateSetFailure"

            (Get-Variable -Name $name -ValueOnly) | Should -Be "ok"
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }
}
