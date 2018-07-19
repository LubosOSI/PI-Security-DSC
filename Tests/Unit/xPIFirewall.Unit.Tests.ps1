#region HEADER

# Modules to test.
$script:DSCModuleName = 'PISecurityDSC'
$script:DSCResourceName = 'xPIFirewall'

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
        $TargetModule = 'xPIFirewall'
        $TargetObject = 'PIFirewall entry'
        $testAFServer = 'localhost'
        $testHostmask = '10.*.*.*'
        $defaultParameters = @{                 
                                Ensure = "Present"
                                Value = "Allow"
                                Hostmask = $testHostmask
                                PIDataArchive = "localhost"
        }
        $testCases = @{
            DesiredState = @{
                Context = 'When the system is in the desired state'
                InputParameters = $defaultParameters
                MockValue = @{
                                Ensure = "Present"
                                Value = "Allow"
                                Hostmask = $testHostmask
                                PIDataArchive = "localhost"
                }
                Desired = $true
                Verb = "Add"
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
                                Ensure = "Absent"
                                Value = "Allow"
                                Hostmask = $testHostmask
                                PIDataArchive = "localhost"
                }
                MockValue = $defaultParameters
                Desired = $false
                Verb = "Remove"
            }
            NotDesiredStateIncorrectParameter = @{
                Context = 'When the system is not in the desired state because a parameter is incorrect'
                InputParameters = $defaultParameters
                MockValue = @{
                        Ensure = "Absent"
                        Value = "Unknown"
                        Hostmask = $testHostmask
                        PIDataArchive = "localhost"
                    }
                Desired = $false
                Verb = "Add"
            }
            DesiredStateAbsent = @{
                Context = 'When the system is in the desired state because it is absent'
                InputParameters = @{
                                Ensure = "Absent"
                                Value = "Allow"
                                Hostmask = "*.*.*.*"
                                PIDataArchive = "localhost"
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
                $MockResource | Add-Member -MemberType NoteProperty -Name HostMask -Value $InputEntry.HostMask -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name Access -Value $InputEntry.Value -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name Ensure -Value $InputEntry.Ensure -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name PIDataArchive -Value $InputEntry.PIDataArchive -TypeName string
            }
            return $MockResource
        }

        Mock -CommandName Connect-PIDataArchive {
            return $null
        }
        $CommandNoun = "PIFirewallDSC"
        Describe "$TargetModule\Get-TargetResource" {
            
            $testCase = $testCases["DesiredState"]
            Context $testCase.Context {
                Mock -CommandName "Get-$CommandNoun" {
                    Get-MockedResource -InputEntry $testCase.MockValue
                }

                $InputParameters = $testCase.InputParameters
                
                $result = Get-TargetResource -PIDataArchive $InputParameters.PIDataArchive -HostMask $InputParameters.HostMask

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
                
                    $result = Get-TargetResource -PIDataArchive $InputParameters.PIDataArchive -HostMask $InputParameters.HostMask

                    It 'Should return Ensure as Absent' {
                        $result["Ensure"] | Should -Be "Absent"
                    }
                }
            }
        }

        Describe "$TargetModule\Set-TargetResource" {
            
            Mock -CommandName "Add-$CommandNoun" -Verifiable
            Mock -CommandName "Remove-$CommandNoun" -Verifiable

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
