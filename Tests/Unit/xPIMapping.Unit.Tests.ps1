#region HEADER

# Modules to test.
$script:DSCModuleName = 'PISecurityDSC'
$script:DSCResourceName = 'xPIMapping'

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
        $TargetModule = 'xPIMapping'
        $TargetObject = 'PIMapping entry'
        $testPIDataArchive = 'localhost'
        $defaultParameters = @{                 
                                PrincipalName = "Domain\UnitTestWindowsPrinciple"
                                Description = "The correct description."
                                Enabled = $true
                                Ensure = "Present"
                                Identity = "UnitTestIdentity"
                                Name = "UnitTestMapping"
                                PIDataArchive = $testPIDataArchive
        }
        $testCases = @{
            DesiredState = @{
                Context = 'When the system is in the desired state'
                InputParameters = $defaultParameters
                MockValue = @{
                                PrincipalName = "Domain\UnitTestWindowsPrinciple"
                                Description = "The correct description."
                                Enabled = $true
                                Ensure = "Present"
                                Identity = "UnitTestIdentity"
                                Name = "UnitTestMapping"
                                PIDataArchive = $testPIDataArchive
                }
                Desired = $true
                Verb = "Set"
            }
            NotDesiredStateAbsent = @{
                Context = "When the system is not in the desired state because the $TargetObject is absent"
                InputParameters = $defaultParameters
                MockValue = $null
                Desired = $false
                Verb = "Add"
            }
            NotDesiredStatePresent = @{
                Context = "When the system is not in the desired state because the $TargetObject is present"
                InputParameters = @{
                                PIDataArchive = $testPIDataArchive
                                Ensure = "Absent"
                                PrincipalName = "Domain\UnitTestWindowsPrinciple"
                }
                MockValue = $defaultParameters
                Desired = $false
                Verb = "Remove"
            }
            NotDesiredStateIncorrectParameter = @{
                Context = 'When the system is not in the desired state because a parameter is incorrect'
                InputParameters = $defaultParameters
                MockValue = @{
                                PrincipalName = "Domain\UnitTestWindowsPrinciple"
                                Description = "The wrong description!!!"
                                Enabled = $true
                                Ensure = "Present"
                                Identity = "UnitTestIdentity"
                                Name = "UnitTestMapping"
                                PIDataArchive = $testPIDataArchive
                    }
                Desired = $false
                Verb = "Set"
            }
            NotDesiredStateRename = @{
                Context = 'When the system is not in the desired state because it has the wrong name'
                InputParameters = $defaultParameters
                MockValue = @{
                                PrincipalName = "Domain\UnitTestWindowsPrinciple"
                                Description = "The wrong description!!!"
                                Enabled = $true
                                Ensure = "Present"
                                Identity = "UnitTestIdentity"
                                Name = "UnitTestMapping_Incorrect"
                                PIDataArchive = $testPIDataArchive
                    }
                Desired = $false
                Verb = "Rename"
            }
            DesiredStateAbsent = @{
                Context = 'When the system is in the desired state because it is absent'
                InputParameters = @{
                                PIDataArchive = $testPIDataArchive
                                Ensure = "Absent"
                                PrincipalName = "Domain\UnitTestWindowsPrinciple"
                }
                MockValue = $null
                Desired = $true
                Verb = "Remove"
            }
        }

        function Get-MockedResource
        {
            param(
                [System.Collections.Hashtable] $InputEntry
            )
            if($null -eq $InputEntry)
            {
                $MockResource = $null
            }
            else
            {
                $MockResource = New-Object PSCustomObject
                $MockResource | Add-Member -MemberType NoteProperty -Name IsEnabled -Value $InputEntry.Enabled -TypeName boolean
                $MockResource | Add-Member -MemberType NoteProperty -Name Ensure -Value $InputEntry.Ensure -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name Name -Value $InputEntry.Name -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name PrincipalName -Value $InputEntry.PrincipalName -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name Identity -Value $InputEntry.Identity -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name Description -Value $InputEntry.Description -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name PIDataArchive -Value $InputEntry.PIDataArchive -TypeName string
            }
            return $MockResource
        }

        Mock -CommandName Connect-PIDataArchive {
            return $null
        }
        $CommandNoun = "PIMappingDSC"
        Describe "$TargetModule\Get-TargetResource" {
            
            $testCase = $testCases["DesiredState"]
            Context $testCase.Context {
                Mock -CommandName "Get-$CommandNoun" {
                    Get-MockedResource -InputEntry $testCase.MockValue
                }

                $InputParameters = $testCase.InputParameters
                
                $result = Get-TargetResource -PIDataArchive $InputParameters.PIDataArchive -PrincipalName $InputParameters.PrincipalName

                It 'Should return the same values passed' {
                    foreach($parameter in $InputParameters.GetEnumerator())
                    {
                        $result[$parameter.Key] | Should -Be $parameter.Value
                    }
                }
            }
            
            $AbsentCases = @('DesiredStateAbsent','NotDesiredStateAbsent')
            foreach($AbsentCase in $AbsentCases)
            {
                $testCase = $testCases[$AbsentCase]
                Context $testCase.Context {
                    Mock -CommandName "Get-$CommandNoun" {
                        Get-MockedResource -InputEntry $testCase.MockValue
                    }

                    $InputParameters = $testCase.InputParameters
                
                    $result = Get-TargetResource -PIDataArchive $InputParameters.PIDataArchive -PrincipalName $InputParameters.PrincipalName

                    It 'Should return Ensure as Absent' {
                        $result["Ensure"] | Should -Be "Absent"
                    }
                }
            }
        }

        Describe "$TargetModule\Set-TargetResource" {
            
            Mock -CommandName "Add-$CommandNoun" -Verifiable
            Mock -CommandName "Remove-$CommandNoun" -Verifiable
            Mock -CommandName "Set-$CommandNoun" -Verifiable
            Mock -CommandName "Rename-$CommandNoun" -Verifiable

            foreach($key in $testCases.Keys)
            {
                $testCase = $testCases[$key]
                Context $testCase.Context {
                    Mock -CommandName "Get-$CommandNoun" {
                        Get-MockedResource -InputEntry $testCase.MockValue
                    }

                    $InputParameters = $testCase.InputParameters

                    It "Should attempt to $($testCase.Verb) the $TargetObject" {
                        Set-TargetResource @InputParameters
                        Assert-MockCalled -CommandName ($testCase.Verb + "-" + $CommandNoun) -Exactly 1 -Scope It
                    }
                }
            }
        }
        
        Describe "$TargetModule\Test-TargetResource" {
            
            foreach($key in $testCases.Keys)
            {
                $testCase = $testCases[$key]
                Context $testCase.Context {
                    Mock -CommandName "Get-$CommandNoun" {
                        Get-MockedResource -InputEntry $testCase.MockValue
                    }
                    $InputParameters = $testCase.InputParameters

                    It "Should return $($testCase.Desired)" {
                        $result = Test-TargetResource @InputParameters
                        $result | Should -be $testCase.Desired
                    }
                } 
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
