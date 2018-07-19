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

    $PIResource = Get-PIPointDSC -PIDataArchive $PIDataArchive -Name $Name
    $Ensure = Get-PIResource_Ensure -PIResource $PIResource -Verbose:$VerbosePreference

    return @{
                PtSecurity = $PIResource.Attributes.ptsecurity
                Name = $Name
                Ensure = $Ensure
                DataSecurity = $PIResource.Attributes.datasecurity
                PIDataArchive = $PIDataArchive
            }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [System.String]
        $PtSecurity,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $DataSecurity,

        [System.String]
        $PIDataArchive = "localhost"
    )

    if($Ensure -eq 'Absent')
    {
        throw "Removal of PI Points not supported."
    }
    Set-PIPointDSC -PIDataArchive $PIDataArchive -Name $Name -PtSecurity $PtSecurity -DataSecurity $DataSecurity 
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [System.String]
        $PtSecurity,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $DataSecurity,

        [System.String]
        $PIDataArchive = "localhost"
    )

    $PIResource = Get-TargetResource -Name $Name -PIDataArchive $PIDataArchive

    if($PIResource.Ensure -eq 'Present' -and $Ensure -eq 'Present')
    {
        $PtSecurityMatch = Compare-PIDataArchiveACL -Desired $PtSecurity -Current $PIResource.PtSecurity
        $DataSecurityMatch = Compare-PIDataArchiveACL -Desired $DataSecurity -Current $PIResource.DataSecurity

        return $($PtSecurityMatch -and $DataSecurityMatch)
    }
    else
    {
        return $($PIResource.Ensure -eq 'Absent' -and $Ensure -eq 'Absent')
    }
}

function Get-PIPointDSC
{
    param(
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $PIDataArchive = "localhost"
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    $PIResource = Get-PIPoint -Connection $Connection -Name $Name  -Attributes @('ptsecurity','datasecurity')
    return $PIResource
}

function Set-PIPointDSC
{
    param(
        [System.String]
        $PtSecurity,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $DataSecurity,

        [System.String]
        $PIDataArchive = "localhost"
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    Set-PIPoint -Connection $Connection -Name $Name -Attributes @{ ptsecurity=$PtSecurity; datasecurity=$DataSecurity }
}

Export-ModuleMember -Function *-TargetResource