# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe "Issue #8906 - attribute syntax for variable options (expected to fail until implemented)" -Tags "CI" {
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
    WriteErrorId = `$writeErrorId
}
"@))

        $result.Value | Should -Be 42
        $result.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::Constant)
        $result.WriteErrorId | Should -Match "^VariableNotWritable"
    }

    It "[ReadOnly] creates a read-only variable" {
        $name = "issue8906_readonly_1"

        try {
            & ([ScriptBlock]::Create("[ReadOnly()]`$script:$name = 7"))

            (Get-Variable -Name $name).Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
            { & ([ScriptBlock]::Create("`$script:$name = 8")) } | Should -Throw -ErrorId "VariableNotWritable"
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }

    It "[ReadOnly] behavior matches Set-Variable semantics for force update" {
        $name = "issue8906_readonly_2"

        try {
            & ([ScriptBlock]::Create("[ReadOnly()]`$script:$name = 1"))

            $writeError = $null
            Set-Variable -Name $name -Value 2 -ErrorAction SilentlyContinue -ErrorVariable writeError
            $writeError.FullyQualifiedErrorId | Should -Match "^VariableNotWritable"
            (Get-Variable -Name $name -ValueOnly) | Should -Be 1

            Set-Variable -Name $name -Value 3 -Force
            (Get-Variable -Name $name -ValueOnly) | Should -Be 3
            (Get-Variable -Name $name).Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)

            $removeError = $null
            Remove-Variable -Name $name -ErrorAction SilentlyContinue -ErrorVariable removeError
            $removeError.FullyQualifiedErrorId | Should -Match "^VariableNotRemovable"
            [bool](Get-Variable -Name $name -ErrorAction SilentlyContinue) | Should -BeTrue

            Remove-Variable -Name $name -Force
            [bool](Get-Variable -Name $name -ErrorAction SilentlyContinue) | Should -BeFalse
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
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
        $name = "issue8906_readonly_clear"

        try {
            & ([ScriptBlock]::Create("[ReadOnly()]`$script:$name = 21"))

            $clearError = $null
            Clear-Variable -Name $name -ErrorAction SilentlyContinue -ErrorVariable clearError
            $clearError.FullyQualifiedErrorId | Should -Match "^VariableNotWritable"
            (Get-Variable -Name $name -ValueOnly) | Should -Be 21

            Clear-Variable -Name $name -Force
            (Get-Variable -Name $name -ValueOnly) | Should -BeNullOrEmpty
            (Get-Variable -Name $name).Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
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
        $name = "issue8906_existing_readonly"

        try {
            Set-Variable -Name $name -Value 1
            & ([ScriptBlock]::Create("[ReadOnly()]`$script:$name = 2"))

            $variable = Get-Variable -Name $name
            $variable.Value | Should -Be 2
            $variable.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }

    It "[PSConstant] cannot be applied to an existing variable" {
        $name = "issue8906_existing_constant"

        try {
            Set-Variable -Name $name -Value 1

            $errorId = try {
                & ([ScriptBlock]::Create("[PSConstant()]`$script:$name = 2"))
                $null
            }
            catch {
                $_.FullyQualifiedErrorId
            }

            $errorId | Should -Match "^VariableCannotBeMadeConstant"
            $variable = Get-Variable -Name $name
            $variable.Value | Should -Be 1
            $variable.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::None)
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
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
        $name = "issue8906_validation_composition"

        try {
            & ([ScriptBlock]::Create("[ReadOnly()][ValidateRange(1,5)][int]`$script:$name = '3'"))

            $variable = Get-Variable -Name $name
            $variable.Value | Should -BeOfType ([int])
            $variable.Value | Should -Be 3
            $variable.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
            $variable.Attributes.Where({ $_ -is [ValidateRange] }).Count | Should -Be 1
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }

    It "duplicate [ReadOnly] attributes are idempotent" {
        $name = "issue8906_duplicate_readonly"

        try {
            & ([ScriptBlock]::Create("[ReadOnly()][ReadOnly()]`$script:$name = 51"))

            $variable = Get-Variable -Name $name
            $variable.Value | Should -Be 51
            $variable.Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
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
