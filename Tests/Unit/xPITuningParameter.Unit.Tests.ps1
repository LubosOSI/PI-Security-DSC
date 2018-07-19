#region HEADER

# Modules to test.
$script:DSCModuleName = 'PISecurityDSC'
$script:DSCResourceName = 'xPITuningParameter'

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
        $TargetModule = 'xPITuningParameter'
        $TargetObject = 'PITuningParameter entry'
        $testPIDataArchive = 'localhost'
        $defaultParameters = @{                 
                                Name = "UnitTestTuningParameter"
                                Ensure = "Present"
                                PIDataArchive = $testPIDataArchive
                                Value = "1"
        }
        $testCases = @{
            DesiredState = @{
                Context = 'When the system is in the desired state'
                InputParameters = $defaultParameters
                MockValue = @{
                                Name = "UnitTestTuningParameter"
                                Ensure = "Present"
                                PIDataArchive = $testPIDataArchive
                                Value = "1"
                }
                Desired = $true
                Verb = "Set"
            }
            NotDesiredStateAbsent = @{
                Context = "When the system is not in the desired state because the $TargetObject is absent"
                InputParameters = $defaultParameters
                MockValue = $null
                Desired = $false
                Verb = "Set"
            }
            NotDesiredStatePresent = @{
                Context = "When the system is not in the desired state because the $TargetObject is present"
                InputParameters = @{
                                Name = "UnitTestTuningParameter"
                                Ensure = "Absent"
                                PIDataArchive = $testPIDataArchive
                }
                MockValue = $defaultParameters
                Desired = $false
                Verb = "Reset"
            }
            NotDesiredStateIncorrectParameter = @{
                Context = 'When the system is not in the desired state because a parameter is incorrect'
                InputParameters = $defaultParameters
                MockValue = @{
                                Name = "UnitTestTuningParameter"
                                Ensure = "Present"
                                PIDataArchive = $testPIDataArchive
                                Value = "99"
                    }
                Desired = $false
                Verb = "Set"
            }
            DesiredStateAbsent = @{
                Context = 'When the system is in the desired state because it is absent'
                InputParameters = @{
                                Name = "UnitTestTuningParameter"
                                Ensure = "Absent"
                                PIDataArchive = $testPIDataArchive
                }
                MockValue = $null
                Desired = $true
                Verb = "Reset"
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
                $MockResource | Add-Member -MemberType NoteProperty -Name Ensure -Value $InputEntry.Ensure -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name Name -Value $InputEntry.Name -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name PIDataArchive -Value $InputEntry.PIDataArchive -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name Value -Value $InputEntry.Value -TypeName string
            }
            return $MockResource
        }

        Mock -CommandName Connect-PIDataArchive {
            return $null
        }
        $CommandNoun = "PITuningParameterDSC"
        Describe "$TargetModule\Get-TargetResource" {
            
            $testCase = $testCases["DesiredState"]
            Context $testCase.Context {
                Mock -CommandName "Get-$CommandNoun" {
                    Get-MockedResource -InputEntry $testCase.MockValue
                }

                $InputParameters = $testCase.InputParameters
                
                $result = Get-TargetResource -PIDataArchive $InputParameters.PIDataArchive -Name $InputParameters.Name

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
                
                    $result = Get-TargetResource -PIDataArchive $InputParameters.PIDataArchive -Name $InputParameters.Name

                    It 'Should return Ensure as Absent' {
                        $result["Ensure"] | Should -Be "Absent"
                    }
                }
            }
        }

        Describe "$TargetModule\Set-TargetResource" {
            
            Mock -CommandName "Reset-$CommandNoun" -Verifiable
            Mock -CommandName "Set-$CommandNoun" -Verifiable

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
