#region HEADER

# Modules to test.
$script:DSCModuleName = 'PISecurityDSC'
$script:DSCResourceName = 'xAFAccessControl'

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

        $testAFServer = 'localhost'
        $defaultParameters = @{
            AFServer = $testAFServer
            Path = "ExampleDatabase\Elements"
            Identity = "UnitTester"
            Type = "AFSecurityItem"
            Access = "Read, Write, Read Data, Write Data"
            Ensure = "Present"
        }

        function Get-MockedSecurityObjectEntries
        {
            param(
                [System.Collections.ArrayList] $InputEntries
            )
                        
            $MockAFSecurityObject = New-Object "System.Collections.Generic.List[PSCustomObject]"
            foreach($InputEntry in $InputEntries)
            {
                $Identity = New-Object PSCustomObject 
                $Identity | Add-Member -MemberType NoteProperty -Name Name -Value $InputEntry.Identity -TypeName string
                $MockEntry = New-Object PSCustomObject
                $MockEntry | Add-Member -MemberType NoteProperty -Name Name -Value $InputEntry.Name -TypeName string
                $MockEntry | Add-Member -MemberType NoteProperty -Name Identity -Value $Identity 
                $MockEntry | Add-Member -MemberType NoteProperty -Name AllowAccess -Value $InputEntry.AllowAccess -TypeName boolean
                $MockEntry | Add-Member -MemberType NoteProperty -Name Rights -Value $InputEntry.Rights -TypeName string

                $MockAFSecurityObject.Add($MockEntry) | Out-Null
            }

            return $MockAFSecurityObject
        }

        $BaseMockAccess = @{
                            Name = 'UnitTester'
                            Identity = 'UnitTester'
                            AllowAccess = 'True'
                        }

        $DefaultAccess = @{}
        $DefaultAccess += $BaseMockAccess
        $DefaultAccess.Add('Rights','Read, Write, Read Data, Write Data')
        
        $WrongAccess = @{}
        $WrongAccess += $BaseMockAccess
        $WrongAccess.Add('Rights','Read, Write, Read Data, Write Data, Delete, Annotate')
        
        $MockAllAccess = @{}
        $MockAllAccess += $BaseMockAccess
        $MockAllAccess.Add('Rights','All')
        
        $NoAccess = @{}
        
        $OtherUserAccess = @{
                             Name = 'Administrators'
                             Identity = 'Administrators'
                             AllowAccess = 'True'
                             Rights = 'ReadWrite, Delete, Execute, Admin, ReadWriteData, Subscribe, SubscribeOthers, Annotate'
                        }

        $testAbsentParameters = @{
            AFServer = $testAFServer
            Path = "ExampleDatabase\Elements"
            Identity = "UnitTester"
            Type = "AFSecurityItem"
            Access = "Read, Write, Read Data, Write Data"
            Ensure = "Absent"
        }

        $AllAccessParameters = @{
            AFServer = $testAFServer
            Path = "ExampleDatabase\Elements"
            Identity = "UnitTester"
            Type = "AFSecurityItem"
            Access = "Read, Write, Delete, Execute, Admin, Read Data, Write Data, Subscribe, Subscribe Others, Annotate"
            Ensure = "Present"
        }

        $testCases = @{
            DesiredState = @{
                Context = 'When the system is in the desired state'
                InputParameters = $defaultParameters
                MockValues = @(
                    $DefaultAccess,
                    $OtherUserAccess
                )
                Desired = $true
                AddAccess = 0
                RemoveAccess = 0
            }
            DesiredStateAllAccess = @{
                Context = 'When the system is in the desired state with full access'
                InputParameters = $AllAccessParameters
                MockValues = @(
                    $MockAllAccess
                )
                Desired = $true
                AddAccess = 0
                RemoveAccess = 0
            }
            NotDesiredStateAbsent = @{
                Context = 'When the system is not in the desired state because the identity is absent.'
                InputParameters = $defaultParameters
                MockValues = @( $OtherUserAccess )
                Desired = $false
                AddAccess = 1
                RemoveAccess = 0
            }
            NotDesiredStateWrongValue = @{
                Context = 'When the system is not in the desired state because the identity has the wrong access.'
                InputParameters = $defaultParameters
                MockValues = @( $WrongAccess )
                Desired = $false
                AddAccess = 1
                RemoveAccess = 0
            }
            NotDesiredStatePresent = @{
                Context = 'When the system is not in the desired state because the identity is present.'
                InputParameters = $testAbsentParameters
                MockValues = @( $DefaultAccess )
                Desired = $false
                AddAccess = 0
                RemoveAccess = 1
            }
            NotDesiredStateEmptyACL = @{
                Context = 'When the system is not in the desired state because the ACL is null.'
                InputParameters = $defaultParameters
                MockValues = @( $NoAccess )
                Desired = $false
                AddAccess = 1
                RemoveAccess = 0
            }
        }

        # Get
        Describe "$script:DSCResourceName\Get-TargetResource" {

            Mock -CommandName Get-AFSecurityObject {
                    return $null
                }
            
            $testCase = $testCases["DesiredState"]
            Context $testCase.Context {
                
                Mock -CommandName Get-AFSecurityObjectEntries {
                    $values = $testCase.MockValues
                    Get-MockedSecurityObjectEntries $values  
                }
                $InputParameters = $testCase.InputParameters
                
                $result = Get-TargetResource -Type $InputParameters.Type -Path $InputParameters.Path -Identity $InputParameters.Identity -AFServer $InputParameters.AFServer

                It 'Should return the same values passed' {
                    foreach($parameter in $InputParameters.GetEnumerator())
                    {
                        $result[$parameter.Key] | Should -Be $parameter.Value
                    }
                }
            }

            $testCase = $testCases["NotDesiredStateAbsent"]
            Context $testCase.Context {
                Mock -CommandName Get-AFSecurityObjectEntries {
                    $values = $testCase.MockValues
                    Get-MockedSecurityObjectEntries $values  
                }
                $InputParameters = $testCase.InputParameters

                $result = Get-TargetResource -Type $InputParameters.Type -Path $InputParameters.Path -Identity $InputParameters.Identity -AFServer $InputParameters.AFServer

                It 'Should return no access and absent' {
                    $result.Ensure | Should -Be 'Absent'
                    $result.Access | Should -Be 'None'
                }
            }
        }

        # Set
        Describe "$script:DSCResourceName\Set-TargetResource" {
            Mock -CommandName Remove-AFIdentityAccess -Verifiable
            Mock -CommandName Add-AFIdentityAccess -Verifiable

            foreach($key in $testCases.Keys)
            {
                $testCase = $testCases[$key]
                Context $testCase.Context {
                    Mock -CommandName Get-AFSecurityObjectEntries {
                        $values = $testCase.MockValues
                        Get-MockedSecurityObjectEntries $values  
                    }
                    $InputParameters = $testCase.InputParameters

                    if($testCase.RemoveAccess -eq 1)
                    { $ItMessage = 'Should attempt to remove the identity' }
                    elseif($testCase.AddAccess -eq 1)
                    { $ItMessage = 'Should attempt to add the identity' }
                    else
                    { $ItMessage = 'Should not attempt to set the value' }

                    It $ItMessage {
                        Set-TargetResource @InputParameters
                        Assert-MockCalled -CommandName Remove-AFIdentityAccess -Exactly $testCase.RemoveAccess -Scope It
                        Assert-MockCalled -CommandName Add-AFIdentityAccess -Exactly $testCase.AddAccess -Scope It
                    }
                }
            }
        }

        Describe "$script:DSCResourceName\Test-TargetResource" {
            # Run through all the test cases
            foreach($key in $testCases.Keys)
            {
                $testCase = $testCases[$key]
                Context $testCase.Context {
                    Mock -CommandName Get-AFSecurityObjectEntries {
                        $values = $testCase.MockValues
                        Get-MockedSecurityObjectEntries $values  
                    }
                    $InputParameters = $testCase.InputParameters

                    It "Should return $($testCase.Desired)" {
                        $result = Test-TargetResource @InputParameters
                        $result | Should -be $testCase.Desired
                    }
                } 
            }
        }

        Describe "$script:DSCResourceName\ConvertTo-CanonicalAFSecurityRight" {
            
            $abbreviatedValues = @(
                    "r",
                    "w",
                    "d",
                    "x",
                    "a",
                    "rd",
                    "wd",
                    "s",
                    "so",
                    "an"
                )
            $componentValues = @(
                    "Read",
                    "Write",
                    "Delete",
                    "Execute",
                    "Admin",
                    "ReadData",
                    "WriteData",
                    "Subscribe",
                    "SubscribeOthers",
                    "Annotate"
                )
            $specialValues = @(
                    "",
                    "None",
                    "ReadWrite",
                    "Read/Write",
                    "Read Data",
                    "Write Data",
                    "Read/Write Data",
                    "ReadWriteData",
                    "Subscribe Others",
                    "All"
                )
            
            Context 'When supported values are input' {
                
                $SupportedValues = $abbreviatedValues + $componentValues + $specialValues 
                $SupportedValues += $SupportedValues.ToUpper() + $SupportedValues.ToLower()

                It 'Should return AFSecurityRights enumeration values for all items.' {
                    $result = $SupportedValues | % { ConvertTo-CanonicalAFSecurityRight $_ } | ? { $_ -in [System.Enum]::GetNames([OSIsoft.AF.AFSecurityRights]) }
                    $result.Count | Should -be $SupportedValues.Count
                }
            }

            Context 'When supported compound values are input' {
                $compoundValues = @()
                for($i=0; $i -lt $abbreviatedValues.Length; $i++)
                {
                    $compoundValues += $abbreviatedValues[0..$i] -join ","
                    $compoundValues += $abbreviatedValues[$i..$abbreviatedValues.Length] -join ","
                }

                It 'Should return AFSecurityRights enumeration that resolves to a string instead of an integer.' {
                    foreach($compoundValue in $compoundValues)
                    {
                        [System.Boolean] $result = $false
                        $test = ConvertTo-CanonicalAFSecurityRight $compoundValue
                        [System.Int32]::TryParse($test.ToString(), [System.Globalization.NumberStyles]::Integer, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$result)
                        $result | Should -be $false
                    }
                }
            }

            Context 'When an unsupported value is input' {
                $UnsupportedValue = "Garbage"

                It 'Should throw an error.' {
                   { ConvertTo-CanonicalAFSecurityRight $UnsupportedValue } | Should -Throw "Invalid AFSecurityRight specified: $UnsupportedValue"
                }
            }
        }

        Describe "$script:DSCResourceName\ConvertTo-CanonicalAFSecurityItem" {
            Context 'When supported values are input' {
                $SupportedValues = @(
                    "Default",
                    "Database",
                    "EventFrame",
                    "Element",
                    "ElementTemplate",
                    "Analysis",
                    "Table",
                    "Transfer",
                    "ReferenceType",
                    "EnumerationSet",
                    "Contact",
                    "Notification",
                    "NotificationContactTemplate",
                    "AnalysisTemplate",
                    "Category",
                    "SecurityIdentity",
                    "SecurityMapping",
                    "NotificationRuleTemplate",
                    "NotificationRule",
                    "TableConnection"
                    "Databases",
                    "EventFrames",
                    "Elements",
                    "ElementTemplates",
                    "Analyses",
                    "Tables",
                    "Transfers",
                    "ReferenceTypes",
                    "EnumerationSets",
                    "Contacts",
                    "Notifications",
                    "NotificationContactTemplates",
                    "AnalysisTemplates",
                    "Categories",
                    "SecurityIdentities",
                    "SecurityMappings",
                    "NotificationRuleTemplates",
                    "NotificationRules",
                    "TableConnections",
                    "Event Frames",
                    "Element Templates",
                    "Reference Types",
                    "Enumeration Sets",
                    "Notification Contact Templates",
                    "Analysis Templates",
                    "Security Identities",
                    "Security Mappings",
                    "Notification Rule Templates",
                    "Notification Rules",
                    "Table Connections",
                    "Identities",
                    "Mappings"
                )
                $SupportedValues += $SupportedValues.ToUpper() + $SupportedValues.ToLower()

                It 'Should return AFSecurityItem enumeration values for all items.' {
                    $result = $SupportedValues | % { ConvertTo-CanonicalAFSecurityItem $_ } | ? { $_ -in [System.Enum]::GetNames([OSIsoft.AF.AFSecurityItem]) }
                    $result.Count | Should -be $SupportedValues.Count
                }
            }

            Context 'When an unsupported value is input' {
                $UnsupportedValue = "Garbage"

                It 'Should throw an error.' {
                   { ConvertTo-CanonicalAFSecurityItem $UnsupportedValue } | Should -Throw "Invalid AFSecurityItem specified: $UnsupportedValue"
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
