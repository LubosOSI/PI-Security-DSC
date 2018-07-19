#region HEADER

# Modules to test.
$script:DSCModuleName = 'PISecurityDSC'
$script:DSCResourceName = 'xPIPoint'

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
        $TargetModule = 'xPIPoint'
        $TargetObject = 'PIPoint entry'
        $testPIDataArchive = 'localhost'
        $defaultParameters = @{                 
                                Name = "UnitTest"
                                DataSecurity = "piadmins: A(r,w) | PI Users: A(r)"
                                Ensure = "Present"
                                PIDataArchive = $testPIDataArchive
                                PtSecurity = "piadmins: A(r,w) | PI Users: A(r)"
        }
        $testCases = @{
            DesiredState = @{
                Context = 'When the system is in the desired state'
                InputParameters = $defaultParameters
                MockValues = $defaultParameters.Clone()
                Desired = $true
                Verb = "Set"
            }
            NotDesiredStatePresent = @{
                Context = "When the system is not in the desired state because the $TargetObject is present"
                InputParameters = @{                 
                                        Name = "UnitTest"
                                        Ensure = "Absent"
                                        PIDataArchive = $testPIDataArchive
                }
                MockValues = $defaultParameters.Clone()
                Desired = $false
                Verb = "Remove"
            }
            NotDesiredStateIncorrectParameter = @{
                Context = 'When the system is not in the desired state because a parameter is incorrect'
                InputParameters = $defaultParameters
                MockValues = @{                 
                                        Name = "UnitTest"
                                        DataSecurity = "piadmins: A(r,w) | PI Users: A(r,w)"
                                        Ensure = "Present"
                                        PIDataArchive = $testPIDataArchive
                                        PtSecurity = "piadmins: A(r,w) | PI Users: A(r,w)"
                }
                Desired = $false
                Verb = "Set"
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
                $MockResourceAttributes = New-Object PSCustomObject
                $MockResourceAttributes | Add-Member -MemberType NoteProperty -Name DataSecurity -Value $InputEntry.DataSecurity -TypeName string
                $MockResourceAttributes | Add-Member -MemberType NoteProperty -Name PtSecurity -Value $InputEntry.PtSecurity -TypeName string
                $MockResource = New-Object PSCustomObject
                $MockResource | Add-Member -MemberType NoteProperty -Name Attributes -Value $MockResourceAttributes
                $MockResource | Add-Member -MemberType NoteProperty -Name Ensure -Value $InputEntry.Ensure -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name Name -Value $InputEntry.Name -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name PIDataArchive -Value $InputEntry.PIDataArchive -TypeName string
            }
            return $MockResource
        }

        Mock -CommandName Connect-PIDataArchive {
            return $null
        }
        
        Describe "$TargetModule\Get-TargetResource" {
            
            $testCase = $testCases["DesiredState"].Clone()
            Context $testCase.Context {
                Mock -CommandName "Get-PIPointDSC" {
                    Get-MockedResource $testCase.MockValues
                }

                $InputParameters = $testCase.InputParameters
                
                $result = Get-TargetResource -Name $InputParameters.Name -PIDataArchive $InputParameters.PIDataArchive

                foreach($parameter in $InputParameters.GetEnumerator())
                {
                    It "Should return the same value for $($parameter.Key) passed" {
                        $result[$parameter.Key] | Should -Be $parameter.Value
                    }
                }
            }
        }

        Describe "$TargetModule\Set-TargetResource" {
            
            Mock -CommandName "Set-PIPointDSC" -Verifiable

            foreach($key in $testCases.Keys)
            {
                $testCase = @{}
                $testCase = $testCases[$key].Clone()
                Context $testCase.Context {
                    $MockAccess = $testCase.MockValues.Clone()
                    Mock -CommandName "Get-PIPointDSC" {
                        Get-MockedResource $testCase.MockValues
                    }

                    $InputParameters = $testCase.InputParameters
                    if($key -eq 'NotDesiredStatePresent')
                    {
                        It 'Should throw: Removal of PI Points not supported.' {
                            { Set-TargetResource @InputParameters } | Should -Throw "Removal of PI Points not supported."
                        }
                    }
                    else
                    {
                        It "Should attempt to set the $TargetObject" {
                            Set-TargetResource @InputParameters
                            Assert-MockCalled -CommandName Set-PIPointDSC -Exactly 1 -Scope It
                        }
                    }
                }
            }
        }
        
        Describe "$TargetModule\Test-TargetResource" {
            
            foreach($key in $testCases.Keys)
            {
                $testCase = $testCases[$key].Clone()
                Context $testCase.Context {
                    $MockAccess = $testCase.MockValues.Clone()
                    Mock -CommandName "Get-PIPointDSC" {
                        Get-MockedResource $testCase.MockValues
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
