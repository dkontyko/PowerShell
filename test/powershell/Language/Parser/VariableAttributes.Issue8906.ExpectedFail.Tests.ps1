# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe "Issue #8906 - attribute syntax for variable options (expected to fail until implemented)" -Tags "CI" {
    It "[PSConstant] creates a constant variable" {
        $name = "issue8906_const_1"

        try {
            & ([ScriptBlock]::Create("[PSConstant()]`$$name = 42"))

            (Get-Variable -Name $name -ValueOnly) | Should -Be 42
            { & ([ScriptBlock]::Create("`$$name = 99")) } | Should -Throw -ErrorId "VariableNotWritable"
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }

    It "[ReadOnly] creates a read-only variable" {
        $name = "issue8906_readonly_1"

        try {
            & ([ScriptBlock]::Create("[ReadOnly()]`$$name = 7"))

            (Get-Variable -Name $name).Options | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
            { & ([ScriptBlock]::Create("`$$name = 8")) } | Should -Throw -ErrorId "VariableNotWritable"
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }

    It "[ReadOnly] behavior matches Set-Variable semantics for force update and force remove" {
        $name = "issue8906_readonly_2"

        try {
            & ([ScriptBlock]::Create("[ReadOnly()]`$$name = 1"))

            $writeError = $null
            Set-Variable -Name $name -Value 2 -ErrorAction SilentlyContinue -ErrorVariable writeError
            $writeError.FullyQualifiedErrorId | Should -Match "^VariableNotWritable"
            (Get-Variable -Name $name -ValueOnly) | Should -Be 1

            Set-Variable -Name $name -Value 3 -Force
            (Get-Variable -Name $name -ValueOnly) | Should -Be 3

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

        try {
            & ([ScriptBlock]::Create("[PSConstant()]`$$name = 10"))

            $writeErrorNoForce = $null
            Set-Variable -Name $name -Value 11 -ErrorAction SilentlyContinue -ErrorVariable writeErrorNoForce
            $writeErrorNoForce.FullyQualifiedErrorId | Should -Match "^VariableNotWritable"
            (Get-Variable -Name $name -ValueOnly) | Should -Be 10

            $writeErrorForce = $null
            Set-Variable -Name $name -Value 12 -Force -ErrorAction SilentlyContinue -ErrorVariable writeErrorForce
            $writeErrorForce.FullyQualifiedErrorId | Should -Match "^VariableNotWritable"
            (Get-Variable -Name $name -ValueOnly) | Should -Be 10

            $removeErrorNoForce = $null
            Remove-Variable -Name $name -ErrorAction SilentlyContinue -ErrorVariable removeErrorNoForce
            $removeErrorNoForce.FullyQualifiedErrorId | Should -Match "^VariableNotRemovable"
            [bool](Get-Variable -Name $name -ErrorAction SilentlyContinue) | Should -BeTrue

            $removeErrorForce = $null
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue -ErrorVariable removeErrorForce
            $removeErrorForce.FullyQualifiedErrorId | Should -Match "^VariableNotRemovable"
            [bool](Get-Variable -Name $name -ErrorAction SilentlyContinue) | Should -BeTrue
        }
        finally {
            Remove-Variable -Name $name -Force -ErrorAction SilentlyContinue
        }
    }
}
