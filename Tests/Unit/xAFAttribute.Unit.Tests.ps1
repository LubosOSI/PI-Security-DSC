#region HEADER

# Modules to test.
$script:DSCModuleName = 'PISecurityDSC'
$script:DSCResourceName = 'xAFAttribute'

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
        $TargetModule = 'xAFAttribute'
        $TargetObject = 'AFAttribute entry'
        $testAFServer = 'localhost'
        $baseParameters = @{                 
                                AFServer = $testAFServer
                                ElementPath = "UnitTestingDatabase\UnitTestingRootElement"
                                Name = "UnitTestingAttribute"
                                Ensure = "Present"
        }
        $defaultParameters = $baseParameters.Clone()
        $defaultParameters.Add("IsArray",$false)
        $defaultParameters.Add("Type","String")
        $defaultParameters.Add("Value",@("test"))
        $boolParameters = $baseParameters.Clone()
        $boolParameters.Add("IsArray",$false)
        $boolParameters.Add("Type","Boolean")
        $boolParameters.Add("Value",@("True"))
        $stringArrayParameters = $baseParameters.Clone()
        $stringArrayParameters.Add("IsArray",$true)
        $stringArrayParameters.Add("Type","String")
        $stringArrayParameters.Add("Value",@("One","Two"))
        $wrongStringArrayParameters = $stringArrayParameters.Clone()
        $wrongStringArrayParameters["Value"] = @("Won","Two")
        $testCases = @{
            DesiredState = @{
                Context = 'When the system is in the desired state'
                InputParameters = $defaultParameters
                MockValue = $defaultParameters.Clone()
                Desired = $true
                Verb = "Set"
            }
            DesiredStateBool = @{
                Context = 'When the system is in the desired state with boolean values'
                InputParameters = $boolParameters
                MockValue = $boolParameters.Clone()
                Desired = $true
                Verb = "Set"
            }
            NotDesiredStateStringArray = @{
                Context = 'When the system is not in the desired state because of the wrong string array'
                InputParameters = $stringArrayParameters
                MockValue = $wrongStringArrayParameters
                Desired = $false
                Verb = "Set"
            }
            NotDesiredStateTypeMismatch = @{
                Context = 'When the system is not in the desired state because of the wrong value type'
                InputParameters = $stringArrayParameters
                MockValue = $boolParameters
                Desired = $false
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
                                AFServer = $testAFServer
                                ElementPath = "UnitTestingDatabase\UnitTestingRootElement"
                                Name = "UnitTestingAttribute"
                                Ensure = "Absent"
                                IsArray = $false
                                Type = "String"
                                Value = @("test")
                }
                MockValue = $defaultParameters
                Desired = $false
                Verb = "Remove"
            }
            NotDesiredStateIncorrectParameter = @{
                Context = 'When the system is not in the desired state because a parameter is incorrect'
                InputParameters = $defaultParameters
                MockValue = @{
                                AFServer = $testAFServer
                                ElementPath = "UnitTestingDatabase\UnitTestingRootElement"
                                Name = "UnitTestingAttribute"
                                Ensure = "Present"
                                IsArray = $false
                                Type = "String"
                                Value = @("Wrong")
                    }
                Desired = $false
                Verb = "Set"
            }
            DesiredStateAbsent = @{
                Context = 'When the system is in the desired state because it is absent'
                InputParameters = @{
                                AFServer = $testAFServer
                                ElementPath = "UnitTestingDatabase\UnitTestingRootElement"
                                Name = "UnitTestingAttribute"
                                Ensure = "Absent"
                }
                MockValue = $null
                Desired = $true
                Verb = "None"
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
                $MockTypeName = $InputEntry.Type
                if($InputEntry.IsArray)
                {
                    $MockTypeName += "[]"
                }
                $MockType = New-Object PSCustomObject
                $MockType | Add-Member -MemberType NoteProperty -Name Name -Value $MockTypeName -TypeName string
                $MockResource = New-Object PSCustomObject
                $MockResource | Add-Member -MemberType NoteProperty -Name Name -Value $InputEntry.Name -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name AFServer -Value $InputEntry.AFServer -TypeName string
                $MockResource | Add-Member -MemberType NoteProperty -Name Type -Value $MockType
            }
            return $MockResource
        }

        function Get-MockedResourceValue
        {
            param(
                [System.Collections.Hashtable] $InputEntry
            )
            return $InputEntry.Value
        }

        $CommandNoun = "AFAttributeDSC"
        Describe "$TargetModule\Get-TargetResource" {
            
            $testCase = $testCases["DesiredState"]
            Context $testCase.Context {
                Mock -CommandName "Get-AFAttributeDSC" {
                    Get-MockedResource -InputEntry $testCase.MockValue
                }
                Mock -CommandName "Get-AFAttributeValueDSC" {
                    Get-MockedResourceValue -InputEntry $testCase.MockValue
                }

                $InputParameters = $testCase.InputParameters
                
                $result = Get-TargetResource -Ensure $InputParameters.Ensure -ElementPath $InputParameters.ElementPath -Name $InputParameters.Name -AFServer $InputParameters.AFServer

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
                    Mock -CommandName "Get-AFAttributeDSC" {
                        Get-MockedResource -InputEntry $testCase.MockValue
                    }
                    Mock -CommandName "Get-AFAttributeValueDSC" {
                        Get-MockedResourceValue -InputEntry $testCase.MockValue
                    }

                    $InputParameters = $testCase.InputParameters
                
                    $result = Get-TargetResource -Ensure $InputParameters.Ensure -ElementPath $InputParameters.ElementPath -Name $InputParameters.Name -AFServer $InputParameters.AFServer

                    It 'Should return Ensure as Absent' {
                        $result["Ensure"] | Should -Be "Absent"
                    }
                }
            }
        }

        Describe "$TargetModule\Set-TargetResource" {
            
            Mock -CommandName "Add-AFAttributeDSC" -Verifiable
            Mock -CommandName "Remove-AFAttributeDSC" -Verifiable
            Mock -CommandName "Set-AFAttributeDSC" -Verifiable

            foreach($key in $testCases.Keys)
            {
                $testCase = $testCases[$key]
                Context $testCase.Context {
                    Mock -CommandName "Get-AFAttributeDSC" {
                        Get-MockedResource -InputEntry $testCase.MockValue
                    }
                    Mock -CommandName "Get-AFAttributeValueDSC" {
                        Get-MockedResourceValue -InputEntry $testCase.MockValue
                    }

                    $InputParameters = $testCase.InputParameters

                    It "Should attempt to $($testCase.Verb) the $TargetObject" {
                        Set-TargetResource @InputParameters
                        if($testCase.Verb -eq 'None')
                        {
                            Assert-MockCalled -CommandName ("Add-AFAttributeDSC") -Exactly 0 -Scope It
                            Assert-MockCalled -CommandName ("Remove-AFAttributeDSC") -Exactly 0 -Scope It
                            Assert-MockCalled -CommandName ("Set-AFAttributeDSC") -Exactly 0 -Scope It
                        }
                        else
                        {
                            Assert-MockCalled -CommandName ($testCase.Verb + "-AFAttributeDSC") -Exactly 1 -Scope It
                        }
                    }
                }
            }
        }
        
        Describe "$TargetModule\Test-TargetResource" {
            
            foreach($key in $testCases.Keys)
            {
                $testCase = $testCases[$key]
                Context $testCase.Context {
                    Mock -CommandName "Get-AFAttributeDSC" {
                        Get-MockedResource -InputEntry $testCase.MockValue
                    }
                    Mock -CommandName "Get-AFAttributeValueDSC" {
                        Get-MockedResourceValue -InputEntry $testCase.MockValue
                    }
                    $InputParameters = $testCase.InputParameters

                    It "Should return $($testCase.Desired)" {
                        $result = Test-TargetResource @InputParameters
                        $result | Should -be $testCase.Desired
                    }
                } 
            }
        }

        Describe "$TargetModule\ConvertFrom-TypeString" {
            $SupportedTypeNames = @(
                    "Boolean",  
                    "Byte",
                    "DateTime",
                    "Double",
                    "Int16",
                    "Int32",
                    "Int64",
                    "Single",
                    "String"
                )
            Context 'When supported array values are entered' {
                
                It 'Should return an array of the correct type' {
                    foreach($SupportedTypeName in $SupportedTypeName)
                    {
                        $result = ConvertFrom-TypeString -TypeName $SupportedTypeName -IsArray $true
                        $result.BaseType.Name | Should -Be 'Array'
                        $result.Name | Should -Be "$SupportedTypeName[]"
                    }
                }
            }
            Context 'When supported non-array values are entered' {
                
                It 'Should return a ValueType of the correct type' {
                    foreach($SupportedTypeName in $SupportedTypeName)
                    {
                        $result = ConvertFrom-TypeString -TypeName $SupportedTypeName -IsArray $false
                        $result.BaseType.Name | Should -Be 'ValueType'
                        $result.Name | Should -Be $SupportedTypeName
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
