#region HEADER

# Modules to test.
$script:DSCModuleName = 'PISecurityDSC'
$script:DSCResourceName = 'xPIAccessControl'

# Import Helper.
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath (Join-Path -Path 'Tests' -ChildPath (Join-Path -Path 'TestHelpers' -ChildPath 'CommonTestHelper.psm1'))) -Force

$TestEnvironment = Initialize-TestEnvironment -DSCModuleName $script:DSCModuleName -DSCResourceName $script:DSCResourceName

function Invoke-TestSetup
{

}

function Invoke-TestCleanup
{
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}

#endregion HEADER

# Begin Testing
try
{
    Invoke-TestSetup

    InModuleScope $script:DSCResourceName {

        $testPIDataArchive = 'myPIDataArchive'
        $defaultParameters = @{
            PIDataArchive = $testPIDataArchive
            Access="Read"
            Name="pireplication"
	        Identity = "piworld"
            Type="PIDatabaseSecurity"
            Ensure="Present"
        }

        # Get
        Describe 'xPIAccessControl\Get-TargetResource' {

            Context 'When the system is in the desired state' {

                Mock -CommandName Get-PIDataArchiveACL {
                    return @{
                        piadmn="Read, Write";
                        piworld="Read"
                    }
                } -Verifiable

                $result = Get-TargetResource -Name $defaultParameters.Name -Type $defaultParameters.Type -Identity $defaultParameters.Identity

                    It 'Should return the state as present' {
                        $result.Ensure | Should -Be 'Present'

                        Assert-MockCalled -CommandName Get-PIDataArchiveACL
                    }

                    It 'Should return the same values passed' {
                        $result.Name | Should -Be $defaultParameters.Name
                        $result.Type | Should -Be $defaultParameters.Type
                        $result.Identity | Should -Be $defaultParameters.Identity

                        Assert-MockCalled -CommandName Get-PIDataArchiveACL
                    }
            }

            Context 'When the system is not in the desired state' {

                Mock -CommandName Get-PIDataArchiveACL {
                    return @{
                        piadmn="Read, Write"
                    }
                } -Verifiable

                $result = Get-TargetResource $defaultParameters.Name -Type $defaultParameters.Type -Identity $defaultParameters.Identity

                It 'Should return absent' {
                    $result.Ensure | Should -Be 'Absent'

                    Assert-MockCalled -CommandName Get-PIDataArchiveACL
                }
            }
        }

        # Set
        Describe 'xPIAccessControl\Set-TargetResource' {
            Mock -CommandName Set-PIDataArchiveACL -Verifiable

            Context 'When the system is in the desired state' {
                Mock -CommandName Get-PIDataArchiveACL {
                    return @{
                        piworld="Read"
                    }
                } -Verifiable

                It 'Should not attempt to set the value' {
                    Set-TargetResource @defaultParameters
                    Assert-MockCalled -CommandName Set-PIDataArchiveACL -Exactly 0 -Scope It
                }
            }

            Context 'When the system is not in the desired state' {
                Mock -CommandName Get-PIDataArchiveACL {
                    return @{
                        piworld="Read, Write"
                    }
                } -Verifiable

                It 'Should attempt to set the value' {
                    Set-TargetResource @defaultParameters
                    Assert-MockCalled -CommandName Set-PIDataArchiveACL -Exactly 1 -Scope It
                }
            }
        }

        # Test
        Describe 'xPIAccessControl\Test-TargetResource' {
            Context 'When the system is in the desired state' {
                Mock -CommandName Get-PIDataArchiveACL {
                    return @{
                        piworld="Read"
                    }
                } -Verifiable

                It 'Should return true.' {
                    $result = Test-TargetResource @defaultParameters
                    $result | Should -be $true
                }
            }

            Context 'When the system is not in the desired state' {
                Mock -CommandName Get-PIDataArchiveACL {
                    return @{
                        piworld="Read, Write"
                    }
                } -Verifiable

                It 'Should return false.' {
                    $result = Test-TargetResource @defaultParameters
                    $result | Should -be $false
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
