# ************************************************************************
# *
# * Copyright 2016 OSIsoft, LLC
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *   <http://www.apache.org/licenses/LICENSE-2.0>
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# *
# ************************************************************************

Import-Module -Name (Join-Path -Path (Split-Path $PSScriptRoot -Parent) `
                               -ChildPath 'CommonResourceHelper.psm1')

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $PIDataArchive = "localhost"
    )

    Write-Verbose "Getting PITuningParameter: '$Name'"
    $PIResource = Get-PITuningParameterDSC -PIDataArchive $PIDataArchive -Name $Name
    $Ensure = Get-PIResource_Ensure -PIResource $PIResource -Verbose:$VerbosePreference

    return @{
                    Name = $PIResource.Name;
                    Default = $PIResource.Default;
                    Ensure = $Ensure;
                    Value = $PIResource.Value;
                    PIDataArchive = $PIDataArchive;
            }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $Value,

        [System.String]
        $PIDataArchive = "localhost"
    )

    if($Ensure -eq 'Absent')
    {
        Write-Verbose "Resetting PITuningParameter: '$Name' to default value."
        Reset-PITuningParameterDSC -PIDataArchive $PIDataArchive -Name $Name
    }
    else
    {
        Write-Verbose "Setting PITuningParameter '$Name' to $Value."
        Set-PITuningParameterDSC -PIDataArchive $PIDataArchive -Name $Name -Value $Value
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $Value,

        [System.String]
        $PIDataArchive = "localhost"
    )

    Write-Verbose "Testing PITuningParameter: '$Name'"
    $PIResource = Get-TargetResource -Name $Name -PIDataArchive $PIDataArchive

    if($PIResource.Ensure -eq 'Present' -and $Ensure -eq 'Present')
    {
        return $($PIResource.Value -eq $Value -or (([System.String]::IsNullOrEmpty($PIResource.Value)) -and $PIResource.Default -eq $Value))
    }
    else
    {
        return $($PIResource.Ensure -eq 'Absent' -and $Ensure -eq 'Absent')
    }
}

function Get-PITuningParameterDSC
{
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $PIDataArchive = "localhost"
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    $PIResource = Get-PITuningParameter -Connection $Connection -Name $Name
    return $PIResource
}

function Set-PITuningParameterDSC
{
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $Value,

        [System.String]
        $PIDataArchive = "localhost"
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    Set-PITuningParameter -Connection $Connection -Name $Name -Value $Value
}

function Reset-PITuningParameterDSC
{
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $PIDataArchive = "localhost"
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    Reset-PITuningParameter -Connection $Connection -Name $Name
}

Export-ModuleMember -Function *-TargetResource
