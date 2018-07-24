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

    Write-Verbose "Getting PI Identity: '$Name'"
    $PIResource = Get-PIIdentityDSC -PIDataArchive $PIDataArchive -Name $Name
    $Ensure = Get-PIResource_Ensure -PIResource $PIResource -Verbose:$VerbosePreference

    return @{
                CanDelete = $PIResource.CanDelete
                IsEnabled = $PIResource.IsEnabled
                PIDataArchive = $PIDataArchive
                Ensure = $Ensure
                AllowUseInTrusts = $PIResource.AllowTrusts
                Name = $Name
                AllowExplicitLogin = $PIResource.AllowExplicitLogin
                AllowUseInMappings = $PIResource.AllowMappings
                Description = $PIResource.Description
            }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [System.Boolean]
        $CanDelete=$true,

        [System.Boolean]
        $IsEnabled=$true,

        [System.String]
        $PIDataArchive = "localhost",

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure="Present",

        [System.Boolean]
        $AllowUseInTrusts=$true,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.Boolean]
        $AllowExplicitLogin=$false,

        [System.Boolean]
        $AllowUseInMappings=$true,

        [System.String]
        $Description=""
    )

    $PIResource = Get-TargetResource -Name $Name -PIDataArchive $PIDataArchive

    # If the resource is supposed to be present we will either add it or set it.
    if($Ensure -eq 'Present')
    {
        # Perform the set operation to correct the resource.
        if($PIResource.Ensure -eq "Present")
        {
            <# Since the identity is present, we must perform due diligence to preserve settings
            not explicitly defined in the config. Remove $PSBoundParameters and those not used
            for the write operation (Ensure, PIDataArchive). #>
            $ParametersToOmit = @('Ensure', 'PIDataArchive') + $PSBoundParameters.Keys
            $ParametersToOmit | Foreach-Object { $null = $PIResource.Remove($_) }

            # Set the parameter values we want to keep to the current resource values.
            Foreach($Parameter in $PIResource.GetEnumerator())
            {
                Set-Variable -Name $Parameter.Key -Value $Parameter.Value -Scope Local
            }

            Write-Verbose "Setting PI Identity $($Name)"
            Set-PIIdentityDSC -PIDataArchive $PIDataArchive -Name $Name `
                                -CanDelete $CanDelete -IsEnabled $IsEnabled `
                                -AllowUseInMappings $AllowUseInMappings -AllowUseInTrusts $AllowUseInTrusts `
                                -AllowExplicitLogin $AllowExplicitLogin -Description $Description
        }
        else
        {
            <# Add the Absent identity. When adding the new identity, we do not need to worry about
            clobbering existing properties because there are none. #>
            Write-Verbose "Adding PI Identity $($Name)"
            Add-PIIdentityDSC -PIDataArchive $PIDataArchive -Name $Name `
                                -CanDelete $CanDelete -IsEnabled $IsEnabled `
                                -AllowUseInMappings $AllowUseInMappings -AllowUseInTrusts $AllowUseInTrusts `
                                -AllowExplicitLogin $AllowExplicitLogin -Description $Description
        }
    }
    # If the resource is supposed to be absent we remove it.
    else
    {
        Write-Verbose "Removing PI Identity $($Name)"
        Remove-PIIdentityDSC -PIDataArchive $PIDataArchive -Name $Name
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [System.Boolean]
        $CanDelete,

        [System.Boolean]
        $IsEnabled,

        [System.String]
        $PIDataArchive = "localhost",

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.Boolean]
        $AllowUseInTrusts,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.Boolean]
        $AllowExplicitLogin,

        [System.Boolean]
        $AllowUseInMappings,

        [System.String]
        $Description
    )

    Write-Verbose "Testing PI Identity: '$Name'"
    $PIResource = Get-TargetResource -Name $Name -PIDataArchive $PIDataArchive

    return $(Compare-PIResourceGenericProperties -Desired $PSBoundParameters -Current $PIResource -Verbose:$VerbosePreference)
}

function Get-PIIdentityDSC
{
    param(
        [System.String]
        $PIDataArchive = "localhost",

        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    $PIResource = Get-PIIdentity -Connection $Connection -Name $Name
    return $PIResource
}

function Set-PIIdentityDSC
{
    param(
        [System.Boolean]
        $CanDelete=$true,

        [System.Boolean]
        $IsEnabled=$true,

        [System.String]
        $PIDataArchive = "localhost",

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure="Present",

        [System.Boolean]
        $AllowUseInTrusts=$true,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.Boolean]
        $AllowExplicitLogin=$false,

        [System.Boolean]
        $AllowUseInMappings=$true,

        [System.String]
        $Description=""
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    Set-PIIdentity -Connection $Connection -Name $Name `
                                -CanDelete:$CanDelete -Enabled:$IsEnabled `
                                -AllowUseInMappings:$AllowUseInMappings -AllowUseInTrusts:$AllowUseInTrusts `
                                -AllowExplicitLogin:$AllowExplicitLogin -Description $Description
}

function Add-PIIdentityDSC
{
    param(
        [System.Boolean]
        $CanDelete=$true,

        [System.Boolean]
        $IsEnabled=$true,

        [System.String]
        $PIDataArchive = "localhost",

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure="Present",

        [System.Boolean]
        $AllowUseInTrusts=$true,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.Boolean]
        $AllowExplicitLogin=$false,

        [System.Boolean]
        $AllowUseInMappings=$true,

        [System.String]
        $Description=""
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    Add-PIIdentity -Connection $Connection -Name $Name `
                                -DisallowDelete:$(!$CanDelete) -Disabled:$(!$IsEnabled) `
                                -DisallowUseInMappings:$(!$AllowUseInMappings) -DisallowUseInTrusts:$(!$AllowUseInTrusts) `
                                -Description $Description
}

function Remove-PIIdentityDSC
{
    param(
        [System.String]
        $PIDataArchive = "localhost",

        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    Remove-PIIdentity -Connection $Connection -Name $Name
}

Export-ModuleMember -Function *-TargetResource