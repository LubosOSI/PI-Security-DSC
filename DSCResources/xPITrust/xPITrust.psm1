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
        [System.String]
        $PIDataArchive = "localhost",

        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    Write-Verbose "Getting PITrust: '$Name'"
    $PIResource = Get-PITrustDSC -PIDataArchive $PIDataArchive -Name $Name
    $Ensure = Get-PIResource_Ensure -PIResource $PIResource -Verbose:$VerbosePreference

    return @{
        WindowsDomain = $PIResource.Domain
        Description = $PIResource.Description
        Enabled = $PIResource.IsEnabled
        PIDataArchive = $PIDataArchive
        NetworkPath = $PIResource.NetworkHost
        WindowsAccount = $PIResource.OSUser
        Name = $Name
        Identity = $PIResource.Identity
        ApplicationName = $PIResource.ApplicationName
        NetMask = $PIResource.NetMask
        IPAddress = $PIResource.IPAddress
        Ensure = $Ensure
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [System.String]
        $WindowsDomain,

        [System.String]
        $Description,

        [System.Boolean]
        $Enabled,

        [System.String]
        $PIDataArchive = "localhost",

        [System.String]
        $NetworkPath,

        [System.String]
        $WindowsAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $Identity,

        [System.String]
        $ApplicationName,

        [System.String]
        $NetMask,

        [System.String]
        $IPAddress,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )

    $PIResource = Get-TargetResource -Name $Name -PIDataArchive $PIDataArchive

    $ParameterTable = @{
            PIDataArchive = $PIDataArchive
            Name = $Name
            Identity = $Identity
            NetworkPath = $NetworkPath
            IPAddress = $IPAddress
            WindowsDomain = $WindowsDomain
            ApplicationName = $ApplicationName
            WindowsAccount = $WindowsAccount
            NetMask = $NetMask
            Description = $Description
            Disabled = !$Enabled
        }

    # If the resource is supposed to be present we will either add it or set it.
    if($Ensure -eq 'Present')
    {
        if($PIResource.Ensure -eq "Present")
        {
            $SpecifiedParameters = [System.String[]]$PSBoundParameters.Keys
            $ParameterTable = Set-PIResourceParametersPreserved -pt $ParameterTable `
                                                                -sp $SpecifiedParameters `
                                                                -cp $PIResource `
                                                                -Verbose:$VerbosePreference
             # Set the relevant props
             Write-Verbose "Setting PITrust: '$Name'"
             Set-PITrustDSC $ParameterTable
        }
        else
        {
            Write-Verbose $PIResource.Ensure
            # Add the Absent Trust with the props.
            Write-Verbose "Adding PITrust: '$Name'"
            Add-PITrustDSC $ParameterTable
        }
    }
    # If the resource is supposed to be absent we remove it.
    else
    {
        Write-Verbose "Removing PITrust: '$($PIResource.Name)'"
        Remove-PITrustDSC -PIDataArchive $PIDataArchive -Name $PIResource.Name
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [System.String]
        $WindowsDomain,

        [System.String]
        $Description,

        [System.Boolean]
        $Enabled,

        [System.String]
        $PIDataArchive = "localhost",

        [System.String]
        $NetworkPath,

        [System.String]
        $WindowsAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $Identity,

        [System.String]
        $ApplicationName,

        [System.String]
        $NetMask,

        [System.String]
        $IPAddress,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )

    Write-Verbose "Testing PITrust: '$Name'"
    $PIResource = Get-TargetResource -Name $Name -PIDataArchive $PIDataArchive

    return $(Compare-PIResourceGenericProperties -Desired $PSBoundParameters -Current $PIResource -Verbose:$VerbosePreference)
}

function Get-PITrustDSC
{
    param(
        [System.String]
        $PIDataArchive = "localhost",

        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    $PIResource = Get-PITrust -Connection $Connection -Name $Name
    return $PIResource
}

function Set-PITrustDSC
{
    param
    (
        [parameter(Mandatory = $true)]
        [System.Collections.Hashtable] 
        $ParameterTable
    )
    $PIDataArchive = $ParameterTable["PIDataArchive"]
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    $ParameterTable.Remove("PIDataArchive")
    $ParameterTable.Add("Connection",$Connection)
    Set-PITrust @ParameterTable
}

function Add-PITrustDSC
{
    param(
        [parameter(Mandatory = $true)]
        [System.Collections.Hashtable] 
        $ParameterTable
    )
    $PIDataArchive = $ParameterTable["PIDataArchive"]
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    $ParameterTable.Remove("PIDataArchive")
    $ParameterTable.Add("Connection",$Connection)
    Add-PITrust @ParameterTable
}

function Remove-PITrustDSC
{
    param(
        [System.String]
        $PIDataArchive = "localhost",

        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    Remove-PITrust -Connection $Connection -Name $Name
}

Export-ModuleMember -Function *-TargetResource
