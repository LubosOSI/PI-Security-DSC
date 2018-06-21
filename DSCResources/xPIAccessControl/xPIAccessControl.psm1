# ************************************************************************
# *
# * Copyright 2018 OSIsoft, LLC
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

		[parameter(Mandatory = $true)]
        [System.String]
        $Type,

		[parameter(Mandatory = $true)]
        [System.String]
        $Identity,

        [System.String]
        $PIDataArchive = "localhost"
    )

    $Access = $null
    $AccessControlList = Get-PIDataArchiveACL -PIDataArchive $PIDataArchive -Name $Name -Type $Type -Format Hashtable -Verbose:$VerbosePreference

    if($AccessControlList.ContainsKey($Identity))
    {
        $Access = $AccessControlList[$Identity]
    }

    if([string]::IsNullOrEmpty($Access))
    {
        $Ensure = "Absent"
        Write-Verbose "Access for $Identity on $Type\$Name not found"
    }
    else
    {
        $Ensure = "Present"
        Write-Verbose "Found $Type\$Name with $Access access for $Identity"
    }

    return @{
                Access = $Access
                Identity = $Identity
                Name = $Name
                Type = $Type
                Ensure = $Ensure
                PIDataArchive = $PIDataArchive
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

		[parameter(Mandatory = $true)]
        [System.String]
        $Type,

		[parameter(Mandatory = $true)]
        [System.String]
        $Identity,

        [parameter(Mandatory = $true)]
        [System.String]
        $Access,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure="Present",

        [System.String]
        $PIDataArchive = "localhost"
    )

    $Access = NormalizeAccessString -Access $Access

    if(!$(Test-TargetResource -Name $Name -Identity $Identity -Type $Type -Access $Access -Ensure $Ensure -PIDataArchive $PIDataArchive))
    {
        # Get a Hashtable of full ACL.
        $AccessControlList = Get-PIDataArchiveACL -PIDataArchive $PIDataArchive -Name $Name -Type $Type -Format Hashtable -Verbose:$VerbosePreference

        # Add or edit the entry for the identity
        if($AccessControlList.ContainsKey($Identity))
        {
            Write-Verbose "Updating entry for $Identity to $Access"
            $AccessControlList[$Identity] = $Access
        }
        else
        {
            Write-Verbose "Adding entry for $Identity with $Access"
            $AccessControlList.Add($Identity, $Access)
        }

        # Write the full updated ACL.
        Set-PIDataArchiveACL -PIDataArchive $PIDataArchive -Name $Name -Type $Type -AccessControlList $AccessControlList -Verbose:$VerbosePreference
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

		[parameter(Mandatory = $true)]
        [System.String]
        $Type,

		[parameter(Mandatory = $true)]
        [System.String]
        $Identity,

        [parameter(Mandatory = $true)]
        [System.String]
        $Access,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure="Present",

        [System.String]
        $PIDataArchive = "localhost"
    )

    $Access = NormalizeAccessString -Access $Access

    [System.Boolean]$result = $false
    $PIResource = Get-TargetResource -Name $Name -Type $Type -Identity $Identity -PIDataArchive $PIDataArchive

    if($PIResource.Ensure -eq $Ensure -and $PIResource.Access -eq $Access)
    {
        $result = $true
    }
    Write-Verbose "Test Desired State result: $result"

    return $result
}

function NormalizeAccessString
{
    param(
        [parameter(Mandatory=$true)]
        [string]
        $Access
    )

    switch($Access)
    {
        "Read,Write" { $Access = "Read, Write"; break }
        "r,w" { $Access = "Read, Write"; break }
        "r"          { $Access = "Read"; break }
        "w"          { $Access = "Write"; break }
    }

    return $Access
}

function ConvertTo-PIDataArchiveACLHashtable
{
    [CmdletBinding()]
    [OutputType([System.Collections.HashTable])]
    param(
        [parameter(Mandatory=$true)]
        [string]
        $String
    )

    Write-Verbose "Converting $String to Hashtable equivalent"
    $hashtableACL = @{}
    $aclEntries = $String.Split('|').Trim()
    foreach ($entry in $aclEntries)
    {
        $splitEntry = $entry.Split(':').Trim()
        $Identity = $splitEntry[0]
        switch($splitEntry[1])
	    {
            "A(r)"   { $Access = "Read" }
            "A(w)"   { $Access = "Write" }
            "A(r,w)" { $Access = "Read, Write" }
            "A()"    { $Access = ""}
        }
        $hashtableACL.Add($Identity, $Access)
    }

    return $hashtableACL
}

function ConvertTo-PIDataArchiveACLString
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [System.Collections.Hashtable]
        $Hashtable
    )

    Write-Verbose "Converting Hashtable to equivalent String"

    [string]$stringACL = ""
    $space = ' '
    $identityDelimiter = ":"
    $entryDelimiter = "|"
    $Keys = $Hashtable.Keys | Sort-Object
    foreach ($key in $Keys)
    {
        switch($Hashtable[$key])
        {
            "Read"        { $Access = "A(r)" }
            "Write"       { $Access = "A(w)" }
            "Read, Write" { $Access = "A(r,w)" }
            ""            { $Access = "A()" }
        }
        $stringACL += $space + $key + $identityDelimiter + $space + $Access + $space + $entryDelimiter
    }
    $stringACL = $stringACL.TrimEnd($entryDelimiter).TrimStart($space)

    Write-Verbose "Converted security String: $stringACL"

    return $stringACL
}

function Get-PIDataArchiveACL
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [System.String]
        $PIDataArchive,
        [parameter(Mandatory=$true)]
        [System.String]
        $Name,
        [parameter(Mandatory=$true)]
        [System.String]
        $Type,
        [parameter(Mandatory=$false)]
        [ValidateSet('String','Hashtable')]
        [System.String]
        $Format='HashTable'
    )

    [System.Collections.Hashtable]$AccessControlList = @{}
    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive

    Write-Verbose "Getting security on $Type\$Name as $Format"
    if ($Type -eq "PIDatabaseSecurity")
	{
        $Security = $(Get-PIDatabasesecurity -Connection $Connection -Name $Name).Security.ToString()
    }
	else
	{
        $Security = $(Get-PIPoint -Connection $Connection -Name $Name -Attributes $Type | Select-Object -ExpandProperty Attributes)[$Type.ToLower()]
	}
    Write-Verbose "Security on $Type\$Name returned: $Security"

    if($Format -eq 'Hashtable')
    {
        $AccessControlList = ConvertTo-PIDataArchiveACLHashtable -String $Security
    }

    return $AccessControlList
}

function Set-PIDataArchiveACL
{
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [System.String]
        $PIDataArchive,
        [parameter(Mandatory=$true)]
        [System.String]
        $Name,
        [parameter(Mandatory=$true)]
        [System.String]
        $Type,
        [parameter(Mandatory=$false)]
        [System.Collections.Hashtable]
        $AccessControlList
    )

    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive

    [System.String]$Security = ConvertTo-PIDataArchiveACLString -Hashtable $AccessControlList

    Write-Verbose "Setting security on $Type\$Name to: $Security"
    if($Type -eq "PIDatabaseSecurity")
    {
        Set-PIDatabaseSecurity -Connection $Connection -Name $Name -Security $Security -Verbose:$VerbosePreference
    }
    else
    {
        Set-PIPoint -Connection $Connection -Name $Name -Attributes @{ $Type.ToLower()=$Security } -Verbose:$VerbosePreference
    }
}

Export-ModuleMember -Function *-TargetResource