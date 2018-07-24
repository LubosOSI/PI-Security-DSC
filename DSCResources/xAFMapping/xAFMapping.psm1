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
        $AFServer,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    Write-Verbose "Getting AF Mapping '$Name'"
    $mapping = Get-AFMappingDSC -AFServer $AFServer -Name $Name

    $Ensure = Get-PIResource_Ensure -PIResource $mapping -Verbose:$VerbosePreference

    $returnValue = @{
        AFServer = $AFServer;
        Name = $mapping.Name;
        Description = $mapping.Description;
        Account = $mapping.AccountDisplayName;
        AFIdentityName = $mapping.SecurityIdentity.Name;
        Ensure = $Ensure;
    }

    $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [System.String]
        $Description,

        [System.String]
        $AFIdentityName,

        [parameter(Mandatory = $true)]
        [System.String]
        $AFServer,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $Account
    )

    $PIResource = Get-TargetResource -Name $Name -AFServer $AFServer

    if($Ensure -eq "Present")
    {
        if($PIResource.Ensure -eq "Present")
        {
            <# Some special handling required if specified Account is different
            than the resource's current Account. Must recreate the AF Mapping
            because the mapping's Account is read-only. #>
            $deleteRequired = $false
            if($Account -ne $PIResource.Account) { $deleteRequired = $true }

            <# Since the identity is present, we must perform due diligence to preserve settings
            not explicitly defined in the config. Remove $PSBoundParameters and those not used
            for the write operation (Ensure, AFServer). #>
            $ParametersToOmit = @('Ensure', 'AFServer') + $PSBoundParameters.Keys
            $ParametersToOmit | Foreach-Object { $null = $PIResource.Remove($_) }

            # Set the parameter values we want to keep to the current resource values.
            Foreach($Parameter in $PIResource.GetEnumerator())
            {
                Set-Variable -Name $Parameter.Key -Value $Parameter.Value -Scope Local
            }

            if($deleteRequired)
            {
                Write-Verbose "Removing and resetting AF Mapping '$Name'"
                Remove-AFMappingDSC -AFServer $AFServer -Name $Name
                Add-AFMappingDSC -AFServer $AFServer -Name $Name -Description $Description -Account $Account -Identity $AFIdentityName
            }
            else
            {
                Write-Verbose "Setting AF Mapping '$Name'"
                Set-AFMappingDSC -AFServer $AFServer -Name $Name -Identity $AFIdentityName -Description $Description
            }
        }
        else
        {
            Write-Verbose "Adding AF Mapping '$Name'"
            Add-AFMappingDSC -AFServer $AFServer -Name $Name -Description $Description -Account $Account -Identity $AFIdentityName
        }
    }
    else
    {
        Write-Verbose "Removing AF Mapping '$Name'"
        Remove-AFMappingDSC -AFServer $AFServer -Name $Name
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [System.String]
        $Description,

        [System.String]
        $AFIdentityName,

        [parameter(Mandatory = $true)]
        [System.String]
        $AFServer,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $Account
    )

    Write-Verbose "Testing AF Mapping: '$Name'"
    $PIResource = Get-TargetResource -Name $Name -AFServer $AFServer -Verbose:$VerbosePreference

    return (Compare-PIResourceGenericProperties -Desired $PSBoundParameters -Current $PIResource)
}

function Get-NTAccount
{
    [CmdletBinding()]
    [OutputType([System.Security.Principal.NTAccount])]
    param
    (
        [string]$AccountName
    )

    $splitAccount = $AccountName -split '\\'
    if($splitAccount.Count -eq 1)
    {
        # No domain specified, assumes local user
        $ntAccount = New-Object System.Security.Principal.NTAccount -ArgumentList $splitAccount[0]
    }
    elseif($splitAccount.Count -eq 2)
    {
        # Pass both domain and username
        $ntAccount = New-Object System.Security.Principal.NTAccount `
            -ArgumentList $splitAccount[0], $splitAccount[1]
    }
    else
    {
        $ErrorActionPreference = 'Stop'
        throw "Invalid Account name specified."
    }

    # Test if account may be resolved correctly
    $oldErrPref = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    try
    {
        $SID = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
        Write-Verbose "Successfully resolved $AccountName to $SID"
    }
    catch
    {
        throw "Could not translate Account name to security identifier."
    }
    finally
    {
        $ErrorActionPreference = $oldErrPref
    }

    return $ntAccount
}

function Get-AFMappingDSC
{
    param(
        [parameter(Mandatory = $true)]
        [System.String]
        $AFServer,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    $AF = Connect-AFServerUsingSDK -AFServer $AFServer

    $mapping = $AF.SecurityMappings[$Name]
    return $mapping
}

function Add-AFMappingDSC
{
    param(
        [parameter(Mandatory = $true)]
        [System.String]
        $AFServer,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $Description,

        [System.Object]
        $Account,

        [System.String]
        $Identity
    )

    $AF = Connect-AFServerUsingSDK -AFServer $AFServer

    # Check if the specified Account and AFIdentityName are valid, stop if not.
    $ErrorActionPreference = 'Stop'
    $ntAccount = Get-NTAccount -AccountName $Account # will throw exception if invalid
    $AFIdentity = Get-ValidAFIdentity -AFServer $AFServer -Identity $Identity

    $mapping = $AF.SecurityMappings.Add($Name, $ntAccount, $AFIdentity, $null)
    $mapping.Description = $Description
    $mapping.CheckIn()
}

function Set-AFMappingDSC
{
    param(
        [parameter(Mandatory = $true)]
        [System.String]
        $AFServer,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $Description,

        [System.String]
        $Identity
    )

    $AF = Connect-AFServerUsingSDK -AFServer $AFServer

    # Check if the specified AFIdentity is valid, stop if not.
    $ErrorActionPreference = 'Stop'
    $AFIdentity = Get-ValidAFIdentity -AFServer $AFServer -Identity $Identity

    $mapping = $AF.SecurityMappings[$Name]
    $mapping.SecurityIdentity = $AFIdentity
    $mapping.Description = $Description
    $mapping.CheckIn()
}

function Remove-AFMappingDSC
{
    param(
        [parameter(Mandatory = $true)]
        [System.String]
        $AFServer,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    $AF = Connect-AFServerUsingSDK -AFServer $AFServer

    $mapping = $AF.SecurityMappings[$Name]
    $AF.SecurityMappings.Remove($mapping) | Out-Null
    $mapping.CheckIn()
}

function Get-ValidAFIdentity
{
    param(
        [parameter(Mandatory = $true)]
        [System.String]
        $AFServer,

        [parameter(Mandatory = $true)]
        [System.String]
        $Identity
    )

    $AFIdentity = Get-AFIdentityDSC -AFServer $AFServer -Name $Identity
    if($null -eq $AFIdentity)
    {
        throw "Could not find existing AF Identity with name '$Identity'."
    }

    return $AFIdentity
}

Export-ModuleMember -Function *-TargetResource