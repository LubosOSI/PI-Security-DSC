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

    $PIResource = Get-PIDatabaseSecurityDSC -PIDataArchive $PIDataArchive -Name $Name
    $Ensure = Get-PIResource_Ensure -PIResource $PIResource -Verbose:$VerbosePreference

    return @{
                Security = $PIResource.Security.ToString()
                Name = $Name
                Ensure = $Ensure
                PIDataArchive = $PIDataArchive
            }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [System.String]
        $Security,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $PIDataArchive = "localhost"
    )

    if($Ensure -eq 'Absent')
    {
        throw "Removing PISecurityDatabase access control is not supported."
    }
    else
    {
        if($Name -eq 'PIBATCHLEGACY')
        {
            if($(Get-Service pibatch -ComputerName $PIDataArchive).Status -ne 'Running')
            {
                $msg = "PI Batch Subsystem must be running to edit database security for PIBATCHLEGACY"
                $msg += " PI Batch Subsystem is no longer needed.  It is recommended to disable the service"
                $msg += " and ignore the PIBATCHLEGACY database security entry."
                throw $msg
            }
        }
        elseif($Name -eq 'AFLINK')
        {
            if($(Get-Service piaflink -ComputerName $PIDataArchive).Status -eq 'Running')
            {
                $msg = "PI AF Link Subsystem must be running to edit database security for PIAFLINK"
                $msg += " If the system does not require MDB synchronization, you can disable the service"
                $msg += " and ignore the PIAFLINK database security entry."
                throw $msg
            }
        }
        Set-PIDatabaseSecurityDSC -PIDataArchive $PIDataArchive -Name $Name -Security $Security
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [System.String]
        $Security,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $PIDataArchive = "localhost"
    )

    $PIResource = Get-TargetResource -Name $Name -PIDataArchive $PIDataArchive

    if($PIResource.Ensure -eq 'Present' -and $Ensure -eq 'Present')
    {
        return $(Compare-PIDataArchiveACL -Desired $Security -Current $PIResource.Security -Verbose:$VerbosePreference)
    }
    else
    {
        return $($PIResource.Ensure -eq 'Absent' -and $Ensure -eq 'Absent')
    }
}

function Get-PIDatabaseSecurityDSC
{
    param(
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $PIDataArchive = "localhost"
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    $PIResource = Get-PIDatabaseSecurity -Connection $Connection -Name $Name
    return $PIResource
}

function Set-PIDatabaseSecurityDSC
{
    param(
        [System.String]
        $Security,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $PIDataArchive = "localhost"
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    Set-PIDatabaseSecurity -Connection $Connection -Name $Name -Security $Security
}

Export-ModuleMember -Function *-TargetResource