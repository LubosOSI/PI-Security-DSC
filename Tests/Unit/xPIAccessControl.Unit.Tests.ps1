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
        $TargetModule = 'xPIAccessControl'
        $TargetObject = 'PIAccessControl entry'
        $testPIDataArchive = 'localhost'
        $defaultParameters = @{                 
                                Identity = "piadmins"
                                Name = "PIPOINT"
                                Type = "PIDatabaseSecurity"
                                Access = "Read, Write"
                                Ensure = "Present"
                                PIDataArchive = $testPIDataArchive
        }
        $testCases = @{
            DesiredState = @{
                Context = 'When the system is in the desired state'
                InputParameters = $defaultParameters
                Access = @{
                                piadmin = "Read, Write"
                                piadmins = "Read, Write"
                                PIWorld = "Read"
                }
                Desired = $true
                Verb = "Set"
            }
            NotDesiredStateAbsent = @{
                Context = "When the system is not in the desired state because the $TargetObject is absent"
                InputParameters = $defaultParameters
                Access = @{
                                piadmin = "Read, Write"
                }
                Desired = $false
                Verb = "Add"
            }
            NotDesiredStatePresent = @{
                Context = "When the system is not in the desired state because the $TargetObject is present"
                InputParameters = @{
                                Identity = "piadmins"
                                Name = "PIPOINT"
                                Type = "PIDatabaseSecurity"
                                Ensure = "Absent"
                                PIDataArchive = $testPIDataArchive
                }
                Access = @{
                                piadmins = "Read, Write"
                }
                Desired = $false
                Verb = "Remove"
            }
            NotDesiredStateIncorrectParameter = @{
                Context = 'When the system is not in the desired state because a parameter is incorrect'
                InputParameters = $defaultParameters
                Access = @{
                                piadmins = "Read"
                }
                Desired = $false
                Verb = "Set"
            }
            DesiredStateAbsent = @{
                Context = 'When the system is in the desired state because it is absent'
                InputParameters = @{
                                Identity = "piadmins"
                                Name = "PIPOINT"
                                Type = "PIDatabaseSecurity"
                                Ensure = "Absent"
                                PIDataArchive = $testPIDataArchive
                }
                Access = @{
                    piadmin = "Read, Write"
                }
                Desired = $true
                Verb = "Remove"
            }
        }

        Mock -CommandName Connect-PIDataArchive {
            return $null
        }
        
        Describe "$TargetModule\Get-TargetResource" {
            
            $testCase = $testCases["DesiredState"].Clone()
            Context $testCase.Context {
                Mock -CommandName "Get-PIAccessControl" {
                    return $testCase.Access
                }

                $InputParameters = $testCase.InputParameters
                
                $result = Get-TargetResource -Name $InputParameters.Name -Type $InputParameters.Type -Identity $InputParameters.Identity -PIDataArchive $InputParameters.PIDataArchive

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
                $testCase = $testCases[$AbsentCase].Clone()
                Context $testCase.Context {
                    Mock -CommandName "Get-PIAccessControl" {
                        return $testCase.Access
                    }

                    $InputParameters = $testCase.InputParameters
                
                    $result = Get-TargetResource -Name $InputParameters.Name -Type $InputParameters.Type -Identity $InputParameters.Identity -PIDataArchive $InputParameters.PIDataArchive

                    It 'Should return Ensure as Absent' {
                        $result["Ensure"] | Should -Be "Absent"
                    }
                }
            }
        }

        Describe "$TargetModule\Set-TargetResource" {
            
            Mock -CommandName "Set-PIAccessControl" -Verifiable

            foreach($key in $testCases.Keys)
            {
                $testCase = @{}
                $testCase = $testCases[$key].Clone()
                Context $testCase.Context {
                    $MockAccess = $testCase.Access.Clone()
                    Mock -CommandName "Get-PIAccessControl" {
                        return $MockAccess
                    }

                    $InputParameters = $testCase.InputParameters
                    if($testCase.Desired)
                    {
                        It "Should not attempt to $($testCase.Verb) the $TargetObject" {
                            Set-TargetResource @InputParameters
                            Assert-MockCalled -CommandName Set-PIAccessControl -Exactly 0 -Scope It
                        }
                    }
                    else
                    {
                        It "Should not attempt to $($testCase.Verb) the $TargetObject" {
                            Set-TargetResource @InputParameters
                            Assert-MockCalled -CommandName Set-PIAccessControl -Exactly 1 -Scope It
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
                    $MockAccess = $testCase.Access.Clone()
                    Mock -CommandName "Get-PIAccessControl" {
                        return $testCase.Access
                    }
                    $InputParameters = $testCase.InputParameters

                    It "Should return $($testCase.Desired)" {
                        $result = Test-TargetResource @InputParameters
                        $result | Should -be $testCase.Desired
                    }
                } 
            }
        }
        
        Describe "$TargetModule\Set-PIAccessControl" {
            
            $TestCase =  @{
                            piadmin = "Read, Write"
                            piadmins = "Read, Write"
                            PIReaders = "Read"
                            PIWorld = ""
                    }
            $types = @(
                        "PIPoint",
                        "PIDatabaseSecurity"
            )
            foreach($type in $types)
            {
                $MockCommandName = "Set-$($type)DSC"
                Mock -CommandName $MockCommandName {} -Verifiable
                Context "When a resource of Type '$type' is called" {
                    It 'Should call the right helper function' {
                        Set-PIAccessControl -PIDataArchive $testPIDataArchive -Name "Test" -Type $type -AccessControlList $TestCase
                        Assert-MockCalled -CommandName $MockCommandName -Exactly 1 -Scope It
                    }
                }
            }
        }

        Describe "$TargetModule\Get-PIAccessControl" {
            
            $TestCase = @{
                    HashTable = @{
                        piadmin = "Read, Write"
                        piadmins = "Read, Write"
                        PIReaders = "Read"
                        PIWorld = ""
                    }
                    String = "piadmin: A(r,w) | piadmins: A(r,w) | PIReaders: A(r) | PIWorld: A()"
                }
            $types = @(
                        "PIPoint",
                        "PIDatabaseSecurity"
            )
            foreach($type in $types)
            {
                $MockCommandName = "Get-$($type)DSC"
                Mock -CommandName $MockCommandName {
                    return $TestCase["String"]
                } -Verifiable
                Context "When a resource of Type '$type' is called" {
                    It 'Should return the correct value' {
                        $result = Get-PIAccessControl -PIDataArchive $testPIDataArchive -Name "Test" -Type $type
                        foreach($key in $result.Keys){ $result[$Key] | Should -Be $TestCase["HashTable"][$key] }
                    }
                    It 'Should call the right helper function' {
                        $result = Get-PIAccessControl -PIDataArchive $testPIDataArchive -Name "Test" -Type $type
                        Assert-MockCalled -CommandName $MockCommandName -Exactly 1 -Scope It
                    }
                }
            }
        }

        Describe "$TargetModule\ConvertTo-PIAccessControlHashtable" {
            
            Context 'When a supported value is passed' {
            $TestCase = @{
                    HashTable = @{
                        piadmin = "Read, Write"
                        piadmins = "Read, Write"
                        PIReaders = "Read"
                        PIWorld = ""
                    }
                    String = "piadmin: A(r,w) | piadmins: A(r,w) | PIReaders: A(r) | PIWorld: A()"
                }

                It 'Should return the expected value' {
                    $result = ConvertTo-PIAccessControlHashtable $TestCase["String"]
                    foreach($key in $result.Keys){ $result[$Key] | Should -Be $TestCase["HashTable"][$key] }
                }
            }
            Context 'When an unsupported value is passed' {
            $InvalidEntry = "D(r,w)"
            $TestCase = "piadmin: $InvalidEntry"
                It "Should throw: Invalid entry '$InvalidEntry' specified." {
                    { ConvertTo-PIAccessControlHashtable $TestCase } | Should -Throw "Invalid entry '$InvalidEntry' specified."
                }
            }
        }

        Describe "$TargetModule\ConvertTo-PIAccessControlString" {
            
            Context 'When a supported value is passed' {
            $TestCase = @{
                    HashTable = @{
                        piadmin = "Read, Write"
                        piadmins = "Read, Write"
                        PIReaders = "Read"
                        PIWorld = ""
                    }
                    String = "piadmin: A(r,w) | piadmins: A(r,w) | PIReaders: A(r) | PIWorld: A()"
                }

                It 'Should return the expected value' {
                    $result = ConvertTo-PIAccessControlString $TestCase["HashTable"]
                    $result | Should -Be $TestCase["String"]
                }
            }
            Context 'When an unsupported value is passed' {
            $TestCase = @{
                        piadmin = "Delete"
                        PIWorld = ""
                    }
                It "Should throw Invalid access string 'Delete' specified." {
                    { ConvertTo-PIAccessControlString $TestCase } | Should -Throw "Invalid access string 'Delete' specified."
                }
            }
        }

        Describe "$TargetModule\ConverTo-CanonicalAccessString" {
            
            Context 'When a supported value is passed' {
                $CanonicalValues = @(
                    "",
                    "Read",
                    "Write",
                    "Read, Write"
                )
                $SupportedValues = @(
                    "read, write",
                    "read,write",
                    "readwrite",
                    "read",
                    "write",
                    "r",
                    "w",
                    "rw",
                    "r,w",
                    "r, w",
                    ""
                )
                $TestValues = $SupportedValues + $SupportedValues.ToUpper()
                $result = $TestValues | Foreach-Object { ConverTo-CanonicalAccessString $_ }

                It 'Should return a canonical value' {
                    $result | Foreach-Object { $_ | Should -BeIn $CanonicalValues }
                }
            }

            Context 'When an unsupported value is passed' {
                $UnsupportedValue = "Garbage"
                It "Should throw: Invalid Access string '$UnsupportedValue' specified." {
                    { ConverTo-CanonicalAccessString $UnsupportedValue } | Should -Throw "Invalid Access string '$UnsupportedValue' specified."
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
