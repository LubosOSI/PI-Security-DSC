#region HEADER

# Modules to test.
$script:DSCModuleName = 'PISecurityDSC'
$script:DSCResourceName = 'xAFIdentity'

# Import Helper.
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath (Join-Path -Path 'Tests' -ChildPath (Join-Path -Path 'TestHelpers' -ChildPath 'CommonTestHelper.psm1'))) -Force

$TestEnvironment = Initialize-TestEnvironment -DSCModuleName $script:DSCModuleName -DSCResourceName $script:DSCResourceName

function Invoke-TestSetup
{
    $loaded = [System.Reflection.Assembly]::LoadWithPartialName("OSIsoft.AFSDK")
    if ($null -eq $loaded) {
        $ErrorActionPreference = 'Stop'
        throw "AF SDK could not be loaded"
    }
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
        $TargetModule = 'xAFIdentity'
        $testAFServer = 'localhost'
        $defaultParameters = @{
                                AFServer=$testAFServer
                                Ensure="Present"
                                Name="World"
                                IsEnabled=$false 
        }
        $testCases = @{
            DesiredState = @{
                Context = 'When the system is in the desired state'
                InputParameters = $defaultParameters
                MockValue = @{
                        AFServer=$testAFServer
                        Ensure="Present"
                        Name="World"
                        IsEnabled=$false
                    }
                Desired = $true
                Verb = "Set"
            }
            NotDesiredStateAbsent = @{
                Context = 'When the system is not in the desired state because the identity is absent'
                InputParameters = $defaultParameters
                MockValue = $null
                Desired = $false
                Verb = "Add"
            }
            NotDesiredStatePresent = @{
                Context = 'When the system is in the desired state because the identity is present'
                InputParameters = @{
                                AFServer=$testAFServer
                                Ensure="Absent"
                                Name="World"
                                IsEnabled=$false 
                }
                MockValue = @{
                        AFServer=$testAFServer
                        Ensure="Present"
                        Name="World"
                        IsEnabled=$false
                    }
                Desired = $false
                Verb = "Remove"
            }
            NotDesiredStateIncorrectParameter = @{
                Context = 'When the system is not in the desired state because a parameter is incorrect'
                InputParameters = $defaultParameters
                MockValue = @{
                        AFServer=$testAFServer
                        Ensure="Present"
                        Name="World"
                        IsEnabled=$true
                    }
                Desired = $false
                Verb = "Set"
            }
            DesiredStateAbsent = @{
                Context = 'When the system is in the desired state because it is absent'
                InputParameters = @{
                                AFServer=$testAFServer
                                Ensure="Absent"
                                Name="World"
                                IsEnabled=$false 
                }
                MockValue = $null
                Desired = $true
                Verb = "Remove"
            }
        }

        function Get-MockedAFIdentity
        {
            param(
                [System.Collections.Hashtable] $InputEntry
            )
            if($null -eq $InputEntry)
            {
                $MockAFIdentity = $null
            }
            else
            {
                $MockAFIdentity = New-Object PSCustomObject
                $MockAFIdentity | Add-Member -MemberType NoteProperty -Name Name -Value $InputEntry.Name -TypeName string
                $MockAFIdentity | Add-Member -MemberType NoteProperty -Name Description -Value $InputEntry.Description -TypeName string
                $MockAFIdentity | Add-Member -MemberType NoteProperty -Name IsEnabled -Value $InputEntry.IsEnabled -TypeName boolean 
            }
            return $MockAFIdentity
        }

        Describe "$TargetModule\Get-TargetResource" {
            
            $testCase = $testCases["DesiredState"]
            Context $testCase.Context {
                Mock -CommandName Get-AFIdentityDSC {
                    Get-MockedAFIdentity -InputEntry $testCase.MockValue
                }

                $InputParameters = $testCase.InputParameters
                
                $result = Get-TargetResource -AFServer $InputParameters.AFServer -Name $InputParameters.Name

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
                    Mock -CommandName Get-AFIdentityDSC {
                        Get-MockedAFIdentity -InputEntry $testCase.MockValue
                    }

                    $InputParameters = $testCase.InputParameters
                
                    $result = Get-TargetResource -AFServer $InputParameters.AFServer -Name $InputParameters.Name

                    It 'Should return Ensure as Absent' {
                        $result["Ensure"] | Should -Be "Absent"
                    }
                }
            }
        }

        Describe "$TargetModule\Set-TargetResource" {
            Mock -CommandName Set-AFIdentityDSC -Verifiable
            Mock -CommandName Remove-AFIdentityDSC -Verifiable
            Mock -CommandName Add-AFIdentityDSC -Verifiable

            foreach($key in $testCases.Keys)
            {
                $testCase = $testCases[$key]
                Context $testCase.Context {
                    Mock -CommandName Get-AFIdentityDSC {
                        Get-MockedAFIdentity -InputEntry $testCase.MockValue
                    }

                    $InputParameters = $testCase.InputParameters
                    switch($testCase.Verb)
                    {
                        "Add"    {
                            $ItMessage = 'Should attempt to add the identity'; break
                        }
                        "Remove" {
                            $ItMessage = 'Should attempt to remove the identity'; break
                        }
                        "Set"    {
                            $ItMessage = 'Should attempt to set the identity'; break
                        }
                    }

                    It $ItMessage {
                        Set-TargetResource @InputParameters
                        Assert-MockCalled -CommandName ($testCase.Verb + "-AFIdentityDSC") -Exactly 1 -Scope It
                    }
                }
            }
        }
        
        Describe "$TargetModule\Test-TargetResource" {
            
            foreach($key in $testCases.Keys)
            {
                $testCase = $testCases[$key]
                Context $testCase.Context {
                    Mock -CommandName Get-AFIdentityDSC {
                        Get-MockedAFIdentity -InputEntry $testCase.MockValue
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
