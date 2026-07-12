# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe "Issue #8906 - attribute syntax for variable options" -Tags "CI" {
    It "[PSConstant] creates a constant variable" {
        $name = "issue8906_const_1"

        $result = & ([ScriptBlock]::Create(@"
[PSConstant()]`$$name = 42
`$writeErrorId = try {
    `$$name = 99
    `$null
}
catch {
    `$_.FullyQualifiedErrorId
}

[pscustomobject]@{
    Value = (Get-Variable -Name $name -ValueOnly)
    Options = (Get-Variable -Name $name).Options
    AttributeCount = (Get-Variable -Name $name).Attributes.Count
    WriteErrorId = `$writeErrorId
}
"@))

        $result.Value | Should -Be 42
        $result.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::Constant)
        $result.AttributeCount | Should -Be 0
        $result.WriteErrorId | Should -Match "^VariableNotWritable"
    }

    It "[ReadOnly] creates a read-only variable" {
        $result = & {
            [ReadOnly()]$value = 7
            $writeErrorId = try {
                $value = 8
                $null
            }
            catch {
                $_.FullyQualifiedErrorId
            }

            $variable = Get-Variable -Name value
            [pscustomobject]@{
                Value = $variable.Value
                Options = $variable.Options
                AttributeCount = $variable.Attributes.Count
                WriteErrorId = $writeErrorId
            }
        }

        $result.Value | Should -Be 7
        $result.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        $result.AttributeCount | Should -Be 0
        $result.WriteErrorId | Should -Match "^VariableNotWritable"
    }

    It "[PSReadOnly] is the explicit form of [ReadOnly]" {
        $result = & {
            [PSReadOnly()]$value = 8
            $variable = Get-Variable -Name value

            [pscustomobject]@{
                Value = $variable.Value
                Options = $variable.Options
                AttributeCount = $variable.Attributes.Count
            }
        }

        $result.Value | Should -Be 8
        $result.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        $result.AttributeCount | Should -Be 0
    }

    It "[ReadOnly] behavior matches Set-Variable semantics for force update" {
        $result = & {
            [ReadOnly()]$value = 1
            $writeError = $null
            Set-Variable -Name value -Value 2 -ErrorAction SilentlyContinue -ErrorVariable writeError
            $valueAfterWrite = $value

            Set-Variable -Name value -Value 3 -Force
            $valueAfterForce = $value
            $optionsAfterForce = (Get-Variable -Name value).Options

            $removeError = $null
            Remove-Variable -Name value -ErrorAction SilentlyContinue -ErrorVariable removeError
            $existsAfterRemove = $null -ne (Get-Variable -Name value -ErrorAction SilentlyContinue)

            Remove-Variable -Name value -Force

            [pscustomobject]@{
                WriteErrorId = $writeError.FullyQualifiedErrorId
                ValueAfterWrite = $valueAfterWrite
                ValueAfterForce = $valueAfterForce
                OptionsAfterForce = $optionsAfterForce
                RemoveErrorId = $removeError.FullyQualifiedErrorId
                ExistsAfterRemove = $existsAfterRemove
                ExistsAfterForceRemove = $null -ne (Get-Variable -Name value -ErrorAction SilentlyContinue)
            }
        }

        $result.WriteErrorId | Should -Match "^VariableNotWritable"
        $result.ValueAfterWrite | Should -Be 1
        $result.ValueAfterForce | Should -Be 3
        $result.OptionsAfterForce | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        $result.RemoveErrorId | Should -Match "^VariableNotRemovable"
        $result.ExistsAfterRemove | Should -BeTrue
        $result.ExistsAfterForceRemove | Should -BeFalse
    }

    It "[PSConstant] behavior matches Set-Variable semantics and never allows mutation" {
        $name = "issue8906_const_2"

        $result = & ([ScriptBlock]::Create(@"
[PSConstant()]`$$name = 10

`$writeErrorNoForce = `$null
Set-Variable -Name $name -Value 11 -ErrorAction SilentlyContinue -ErrorVariable writeErrorNoForce

`$writeErrorForce = `$null
Set-Variable -Name $name -Value 12 -Force -ErrorAction SilentlyContinue -ErrorVariable writeErrorForce

`$removeErrorNoForce = `$null
Remove-Variable -Name $name -ErrorAction SilentlyContinue -ErrorVariable removeErrorNoForce

`$removeErrorForce = `$null
Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue -ErrorVariable removeErrorForce

[pscustomobject]@{
    Value = (Get-Variable -Name $name -ValueOnly)
    Options = (Get-Variable -Name $name).Options
    WriteErrorNoForce = `$writeErrorNoForce.FullyQualifiedErrorId
    WriteErrorForce = `$writeErrorForce.FullyQualifiedErrorId
    RemoveErrorNoForce = `$removeErrorNoForce.FullyQualifiedErrorId
    RemoveErrorForce = `$removeErrorForce.FullyQualifiedErrorId
}
"@))

        $result.Value | Should -Be 10
        $result.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::Constant)
        $result.WriteErrorNoForce | Should -Match "^VariableNotWritable"
        $result.WriteErrorForce | Should -Match "^VariableNotWritable"
        $result.RemoveErrorNoForce | Should -Match "^VariableNotRemovable"
        $result.RemoveErrorForce | Should -Match "^VariableNotRemovable"
    }

    It "[ReadOnly] behavior matches Clear-Variable force semantics" {
        $result = & {
            [ReadOnly()]$value = 21
            $clearError = $null
            Clear-Variable -Name value -ErrorAction SilentlyContinue -ErrorVariable clearError
            $valueBeforeForce = $value

            Clear-Variable -Name value -Force
            $variable = Get-Variable -Name value

            [pscustomobject]@{
                ClearErrorId = $clearError.FullyQualifiedErrorId
                ValueBeforeForce = $valueBeforeForce
                ValueAfterForce = $variable.Value
                OptionsAfterForce = $variable.Options
            }
        }

        $result.ClearErrorId | Should -Match "^VariableNotWritable"
        $result.ValueBeforeForce | Should -Be 21
        $result.ValueAfterForce | Should -BeNullOrEmpty
        $result.OptionsAfterForce | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
    }

    It "[PSConstant] behavior matches Clear-Variable semantics even with force" {
        $name = "issue8906_const_clear"

        $result = & ([ScriptBlock]::Create(@"
[PSConstant()]`$$name = 22

`$clearErrorNoForce = `$null
Clear-Variable -Name $name -ErrorAction SilentlyContinue -ErrorVariable clearErrorNoForce

`$clearErrorForce = `$null
Clear-Variable -Name $name -Force -ErrorAction SilentlyContinue -ErrorVariable clearErrorForce

[pscustomobject]@{
    Value = (Get-Variable -Name $name -ValueOnly)
    Options = (Get-Variable -Name $name).Options
    ClearErrorNoForce = `$clearErrorNoForce.FullyQualifiedErrorId
    ClearErrorForce = `$clearErrorForce.FullyQualifiedErrorId
}
"@))

        $result.Value | Should -Be 22
        $result.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::Constant)
        $result.ClearErrorNoForce | Should -Match "^VariableNotWritable"
        $result.ClearErrorForce | Should -Match "^VariableNotWritable"
    }

    It "[ReadOnly] can be applied to an existing writable variable" {
        $result = & {
            Set-Variable -Name value -Value 1
            [ReadOnly()]$value = 2
            $variable = Get-Variable -Name value

            [pscustomobject]@{
                Value = $variable.Value
                Options = $variable.Options
            }
        }

        $result.Value | Should -Be 2
        $result.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
    }

    It "[PSConstant] cannot be applied to an existing variable" {
        $result = & {
            Set-Variable -Name value -Value 1
            $errorId = try {
                [PSConstant()]$value = 2
                $null
            }
            catch {
                $_.FullyQualifiedErrorId
            }

            $variable = Get-Variable -Name value
            [pscustomobject]@{
                ErrorId = $errorId
                Value = $variable.Value
                Options = $variable.Options
            }
        }

        $result.ErrorId | Should -Match "^VariableCannotBeMadeConstant"
        $result.Value | Should -Be 1
        $result.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::None)
    }

    It "option attributes honor local variable scope" {
        $readOnlyName = "issue8906_local_readonly"
        $constantName = "issue8906_local_constant"

        $result = & ([ScriptBlock]::Create(@"
[ReadOnly()]`$local:$readOnlyName = 31
[PSConstant()]`$local:$constantName = 32

[pscustomobject]@{
    ReadOnlyValue = (Get-Variable -Name $readOnlyName -Scope Local -ValueOnly)
    ReadOnlyOptions = (Get-Variable -Name $readOnlyName -Scope Local).Options
    ConstantValue = (Get-Variable -Name $constantName -Scope Local -ValueOnly)
    ConstantOptions = (Get-Variable -Name $constantName -Scope Local).Options
}
"@))

        $result.ReadOnlyValue | Should -Be 31
        $result.ReadOnlyOptions | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        $result.ConstantValue | Should -Be 32
        $result.ConstantOptions | Should -Be ([System.Management.Automation.ScopedItemOptions]::Constant)
        Get-Variable -Name $readOnlyName -Scope Local -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Variable -Name $constantName -Scope Local -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It "[ReadOnly] honors global variable scope" {
        $name = "issue8906_global_readonly"

        try {
            & ([ScriptBlock]::Create("[ReadOnly()]`$global:$name = 41"))

            $variable = Get-Variable -Name $name -Scope Global
            $variable.Value | Should -Be 41
            $variable.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        }
        finally {
            Remove-Variable -Name $name -Scope Global -Force -ErrorAction SilentlyContinue
        }
    }

    It "option attributes compose with type and validation attributes" {
        $result = & {
            [ReadOnly()][ValidateRange(1,5)][int]$value = '3'
            $variable = Get-Variable -Name value

            [pscustomobject]@{
                Value = $variable.Value
                Options = $variable.Options
                ValidateRangeCount = $variable.Attributes.Where({ $_ -is [ValidateRange] }).Count
            }
        }

        $result.Value | Should -BeOfType ([int])
        $result.Value | Should -Be 3
        $result.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        $result.ValidateRangeCount | Should -Be 1
    }

    It "duplicate [ReadOnly] attributes are idempotent" {
        $result = & {
            [ReadOnly()][ReadOnly()]$value = 51
            $variable = Get-Variable -Name value

            [pscustomobject]@{
                Value = $variable.Value
                Options = $variable.Options
            }
        }

        $result.Value | Should -Be 51
        $result.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
    }

    It "[ReadOnly] and [PSConstant] combine like ScopedItemOptions flags" {
        $name = "issue8906_combined_options"
        $expectedOptions = [System.Management.Automation.ScopedItemOptions]::ReadOnly -bor
            [System.Management.Automation.ScopedItemOptions]::Constant

        $result = & ([ScriptBlock]::Create(@"
[ReadOnly()][PSConstant()]`$$name = 61

`$writeError = `$null
Set-Variable -Name $name -Value 62 -Force -ErrorAction SilentlyContinue -ErrorVariable writeError

[pscustomobject]@{
    Value = (Get-Variable -Name $name -ValueOnly)
    Options = (Get-Variable -Name $name).Options
    WriteErrorId = `$writeError.FullyQualifiedErrorId
}
"@))

        $result.Value | Should -Be 61
        $result.Options | Should -Be $expectedOptions
        $result.WriteErrorId | Should -Match "^VariableNotWritable"
    }
}
