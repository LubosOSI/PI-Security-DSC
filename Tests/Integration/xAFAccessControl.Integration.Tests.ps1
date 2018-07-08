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
    $resultsFolder = Join-Path -Path (Split-Path -Path $PSScriptRoot) -ChildPath "Results"
    $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $configFile

    Describe "$script:DSCResourceName\Integration" {
        
        $configurationName = "$($script:DSCResourceName)_GrantAccess"
         
            Context "When using configuration $($configurationName)" {
                
                It 'Should compile and apply the MOF without throwing' {
                    {
                        $configurationParameters = @{
                            Access            = "Read, ReadData"
                            OutputPath        = $resultsFolder
                            ConfigurationData = $ConfigurationData
                        }

                        & $configurationName @configurationParameters

                        $startDscConfigurationParameters = @{
                            Path         = $resultsFolder
                            ComputerName = 'localhost'
                            Wait         = $true
                            Verbose      = $true
                            Force        = $true
                            ErrorAction  = 'Stop'
                        }

                        Start-DscConfiguration @startDscConfigurationParameters
                    } | Should -Not -Throw
                }

                It 'Should call Get-DscConfiguration without error' {
                    { $script:currentConfiguration = Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
                }

                It 'Should set the resource with all the correct parameters' {
                    $resourceCurrentState = $script:currentConfiguration | Where-Object { 
                        $_.ConfigurationName -eq $configurationName -and $_.CimClassName -eq $script:DSCResourceName 
                    }
                    foreach($resource in $resourceCurrentState)
                    {
                        $resource.Access | Should -Match $configurationParameters.Access
                        $resource.Ensure | Should -Be "Present"
                    }
                }
            }
        
        $configurationName = "$($script:DSCResourceName)_RevokeAccess"
            
        Context "When using configuration $($configurationName)" {
                
            It 'Should compile and apply the MOF without throwing' {
                {
                    $configurationParameters = @{
                        OutputPath        = $resultsFolder
                        ConfigurationData = $ConfigurationData
                    }

                    & $configurationName @configurationParameters

                    $startDscConfigurationParameters = @{
                        Path         = $resultsFolder
                        ComputerName = 'localhost'
                        Wait         = $true
                        Verbose      = $true
                        Force        = $true
                        ErrorAction  = 'Stop'
                    }

                    Start-DscConfiguration @startDscConfigurationParameters
                } | Should -Not -Throw
            }

            It 'Should call Get-DscConfiguration without error' {
                { $script:currentConfiguration = Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should set the resource with all the correct parameters' {
                $resourceCurrentState = $script:currentConfiguration | Where-Object { 
                    $_.ConfigurationName -eq $configurationName -and $_.CimClassName -eq $script:DSCResourceName 
                }
                foreach($resource in $resourceCurrentState)
                {
                    $resource.Ensure | Should -Be "Absent"
                }
            }
        }
    }
}
finally
{
    $configurationName = "$($script:DSCResourceName)_CleanUpAccessTest"
    $configurationParameters = @{
                        OutputPath        = $resultsFolder
                        ConfigurationData = $ConfigurationData
    }

    & $configurationName @configurationParameters

    $startDscConfigurationParameters = @{
                        Path         = $resultsFolder
                        ComputerName = 'localhost'
                        Wait         = $true
                        Verbose      = $true
                        Force        = $true
                        ErrorAction  = 'Stop'
    }

    Start-DscConfiguration @startDscConfigurationParameters
    Invoke-TestCleanup
}