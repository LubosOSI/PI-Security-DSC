#region HEADER

# Modules to test.
$script:DSCModuleName = 'PISecurityDSC'
$script:DSCResourceName = 'CommonResourceHelper'

# Import Helper.
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath (Join-Path -Path 'Tests' -ChildPath (Join-Path -Path 'TestHelpers' -ChildPath 'CommonTestHelper.psm1'))) -Force

Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath (Join-Path -Path 'DSCResources' -ChildPath 'CommonResourceHelper.psm1')) -Force

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
    
}

#endregion HEADER

# Begin Testing
try
{
    Invoke-TestSetup

    InModuleScope $script:DSCResourceName {
        
        $TargetModule = 'CommonResourceHelper'
        Describe "$TargetModule\Get-PIResource_Ensure" {
            
            Context 'When a null value is received' {

                It 'Should return absent.' {
                    $result = Get-PIResource_Ensure -PIResource $nullResource
                    $result | Should -be 'Absent'
                }
            }

            Context 'When a resource object is received' {
                $PIResource = @{
                    Name = "test"
                    Property1 = 1
                }

                It 'Should return present.' {
                    $result = Get-PIResource_Ensure $PIResource
                    $result | Should -be 'Present'
                }
            }
        }

        Describe "$TargetModule\Compare-PIDataArchiveACL" {
            
            Context 'When matching values are received' {
                $Desired = "piadmin: A(r,w) | piadmins: A(r,w) | PIWorld: A(r) | PI Readers: A()"
                
                It 'Should return true.' {
                    $result = Compare-PIDataArchiveACL -Desired $Desired -Current $Desired
                    $result | Should -be $true
                }
            }

            Context 'When equivalent values are received in a different order' {
                $Current = "PI Readers: A() | PIWorld: A(r) | piadmin: A(r,w) | piadmins: A(r,w)"
                $Desired = "piadmin: A(r,w) | piadmins: A(r,w) | PIWorld: A(r) | PI Readers: A()"

                It 'Should return true.' {
                    $result = Compare-PIDataArchiveACL -Desired $Desired -Current $Current
                    $result | Should -be $true
                }
            }

            Context 'When different values are received' {
                $Current = "PI Readers: A() | PIWorld: A(r) | piadmin: A(r,w)"
                $Desired = "piadmin: A(r,w) | piadmins: A(r,w) | PIWorld: A(r) | PI Readers: A()"

                It 'Should return false.' {
                    $result = Compare-PIDataArchiveACL -Desired $Desired -Current $Current
                    $result | Should -be $false
                }
            }

            Context 'When null values are received' {
                $Current = $Desired = ""

                It 'Should throw.' {
                    { Compare-PIDataArchiveACL -Desired $Desired -Current $Current } | Should -Throw
                }
            }
        }

        Describe "$TargetModule\Compare-PIResourceGenericProperties" {
            
            Context 'When matching resources are received' {
                
                $Current = @{
                    Ensure = "Present"
                    Property1 = 1
                    Property2 = "2"
                    Property3 = ""
                    Property4 = "test"
                }
                $Desired = @{
                    Ensure = "Present"
                    Property1 = 1
                    Property2 = "2"
                    Property3 = ""
                }
                
                It 'Should return true.' {
                    $result = Compare-PIResourceGenericProperties -Desired $Desired -Current $Current
                    $result | Should -be $true
                }
            }

            $Current = @{
                    Ensure = "Present"
                    Property1 = 1
                    Property2 = $null
                }

            Context 'When the desired resource has additional properties' {

                $Desired = @{
                    Ensure = "Present"
                    Property1 = 1
                    Property2 = "2"
                }
                
                It 'Should return false.' {
                    $result = Compare-PIResourceGenericProperties -Desired $Desired -Current $Current
                    $result | Should -be $false
                }
            }

            Context 'When non-matching Ensure resources are received' {
                
                $Desired = @{
                    Ensure = "Absent"
                    Property1 = 1
                }
                
                It 'Should return false.' {
                    $result = Compare-PIResourceGenericProperties -Desired $Desired -Current $Current
                    $result | Should -be $false
                }
            }

            Context 'When non-matching property resources are received' {

                $Desired = @{
                    Ensure = "Present"
                    Property1 = 2
                }
                
                It 'Should return false.' {
                    $result = Compare-PIResourceGenericProperties -Desired $Desired -Current $Current
                    $result | Should -be $false
                }
            }
        }

        Describe "$TargetModule\Set-PIResourceParametersPreserved" {

            Context 'When all parameters are specified' {
                [System.Collections.Hashtable] $ParameterTable = @{
                    P1 = "1"
                    P2 = "2"
                    P3 = "3"
                }
                [System.String[]] $SpecifiedParameters = @(
                    "P1",
                    "P2",
                    "P3"
                )
                [System.Collections.Hashtable] $CurrentParameters = @{
                    P1 = "4"
                    P2 = "5"
                    P3 = "6"
                }
                
                It 'Should return the ParameterTable for the command.' {
                    $result = Set-PIResourceParametersPreserved -pt $ParameterTable -sp $SpecifiedParameters -cp $CurrentParameters
                    $result | Should -be $ParameterTable
                }
            }

            Context 'When no parameters are specified' {
                [System.Collections.Hashtable] $ParameterTable = @{
                    P1 = "1"
                    P2 = "2"
                    P3 = "3"
                }
                [System.String[]] $SpecifiedParameters = @()
                [System.Collections.Hashtable] $CurrentParameters = @{
                    P1 = "4"
                    P2 = "5"
                    P3 = "6"
                }
                It 'Should throw.' {
                    { Set-PIResourceParametersPreserved -pt $ParameterTable -sp $SpecifiedParameters -cp $CurrentParameters } | Should -Throw "Cannot bind argument to parameter 'SpecifiedParameters' because it is an empty array."
                }
            }

            Context 'When a subset of parameters are specified' {
                [System.Collections.Hashtable] $ParameterTable = @{
                    P1 = "1"
                    P2 = "2"
                    P3 = "3"
                }
                [System.String[]] $SpecifiedParameters = @(
                    "P1",
                    "P2"
                )
                [System.Collections.Hashtable] $CurrentParameters = @{
                    P1 = "4"
                    P2 = "5"
                    P3 = "6"
                }
                It 'Should replace those specific parameters.' {
                    $ExpectedResult = @{
                        P1 = "1"
                        P2 = "2"
                        P3 = "6"
                    }
                    $result = Set-PIResourceParametersPreserved -pt $ParameterTable -sp $SpecifiedParameters -cp $CurrentParameters
                    foreach($value in $result.GetEnumerator())
                    {
                        $result[$value.Key] | Should -Be $ExpectedResult[$value.Key]
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
