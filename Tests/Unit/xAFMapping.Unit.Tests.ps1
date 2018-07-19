#region HEADER

# Modules to test.
$script:DSCModuleName = 'PISecurityDSC'
$script:DSCResourceName = 'xAFMapping'

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
        $TargetModule = 'xAFMapping'
        $testAFServer = 'localhost'
        $defaultParameters = @{
                                Description = "This is a mapping"
                                AFIdentityName = "UnitTestIdentity"
                                AFServer = $testAFServer
                                Name = "UnitTestMapping"
                                Ensure = "Present"
                                Account = "UnitTestAccount"
        }
        $testCases = @{
            DesiredState = @{
                Context = 'When the system is in the desired state'
                InputParameters = $defaultParameters
                MockValue = @{
                        Description = "This is a mapping"
                        AFIdentityName = "UnitTestIdentity"
                        AFServer = $testAFServer
                        Name = "UnitTestMapping"
                        Ensure = "Present"
                        Account = "UnitTestAccount"
                    }
                Desired = $true
                Verb = "Set"
            }
            NotDesiredStateAbsent = @{
                Context = 'When the system is not in the desired state because the mapping is absent'
                InputParameters = $defaultParameters
                MockValue = $null
                Desired = $false
                Verb = "Add"
            }
            NotDesiredStatePresent = @{
                Context = 'When the system is in the desired state because the mapping is present'
                InputParameters = @{
                                AFServer = $testAFServer
                                Name = "UnitTestMapping"
                                Ensure = "Absent" 
                }
                MockValue = $defaultParameters
                Desired = $false
                Verb = "Remove"
            }
            NotDesiredStateIncorrectParameter = @{
                Context = 'When the system is not in the desired state because a parameter is incorrect'
                InputParameters = $defaultParameters
                MockValue = @{
                        Description = "Wrong description!!!"
                        AFIdentityName = "UnitTestIdentity"
                        AFServer = $testAFServer
                        Name = "UnitTestMapping"
                        Ensure = "Present"
                        Account = "UnitTestAccount"
                    }
                Desired = $false
                Verb = "Set"
            }
            DesiredStateAbsent = @{
                Context = 'When the system is in the desired state because it is absent'
                InputParameters = @{
                                AFServer = $testAFServer
                                Name = "UnitTestMapping"
                                Ensure = "Absent" 
                }
                MockValue = $null
                Desired = $true
                Verb = "Remove"
            }
        }

        function Get-MockedAFMapping
        {
            param(
                [System.Collections.Hashtable] $InputEntry
            )
            if($null -eq $InputEntry)
            {
                $MockAFMapping = $null
            }
            else
            {
                $MockAFMapping = New-Object PSCustomObject
                $SecurityIdentity = New-Object PSCustomObject
                $SecurityIdentity | Add-Member -MemberType NoteProperty -Name Name -Value $InputEntry.AFIdentityName -TypeName string
                $MockAFMapping | Add-Member -MemberType NoteProperty -Name SecurityIdentity -Value $SecurityIdentity
                $MockAFMapping | Add-Member -MemberType NoteProperty -Name Description -Value $InputEntry.Description -TypeName string
                $MockAFMapping | Add-Member -MemberType NoteProperty -Name Ensure -Value $InputEntry.Ensure -TypeName string
                $MockAFMapping | Add-Member -MemberType NoteProperty -Name AccountDisplayName -Value $InputEntry.Account -TypeName string
                $MockAFMapping | Add-Member -MemberType NoteProperty -Name Name -Value $InputEntry.Name -TypeName string
                $MockAFMapping | Add-Member -MemberType NoteProperty -Name AFServer -Value $InputEntry.AFServer -TypeName string
            }
            return $MockAFMapping
        }

        Describe "$TargetModule\Get-TargetResource" {
            
            $testCase = $testCases["DesiredState"]
            Context $testCase.Context {
                Mock -CommandName Get-AFMappingDSC {
                    Get-MockedAFMapping -InputEntry $testCase.MockValue
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
                    Mock -CommandName Get-AFMappingDSC {
                        Get-MockedAFMapping -InputEntry $testCase.MockValue
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
            Mock -CommandName Set-AFMappingDSC -Verifiable
            Mock -CommandName Remove-AFMappingDSC -Verifiable
            Mock -CommandName Add-AFMappingDSC -Verifiable

            foreach($key in $testCases.Keys)
            {
                $testCase = $testCases[$key]
                Context $testCase.Context {
                    Mock -CommandName Get-AFMappingDSC {
                        Get-MockedAFMapping -InputEntry $testCase.MockValue
                    }

                    $InputParameters = $testCase.InputParameters
                    switch($testCase.Verb)
                    {
                        "Add"    {
                            $ItMessage = 'Should attempt to add the mapping'; break
                        }
                        "Remove" {
                            $ItMessage = 'Should attempt to remove the mapping'; break
                        }
                        "Set"    {
                            $ItMessage = 'Should attempt to set the mapping'; break
                        }
                    }

                    It $ItMessage {
                        Set-TargetResource @InputParameters
                        Assert-MockCalled -CommandName ($testCase.Verb + "-AFMappingDSC") -Exactly 1 -Scope It
                    }
                }
            }
        }
        
        Describe "$TargetModule\Test-TargetResource" {
            
            foreach($key in $testCases.Keys)
            {
                $testCase = $testCases[$key]
                Context $testCase.Context {
                    Mock -CommandName Get-AFMappingDSC {
                        Get-MockedAFMapping -InputEntry $testCase.MockValue
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
