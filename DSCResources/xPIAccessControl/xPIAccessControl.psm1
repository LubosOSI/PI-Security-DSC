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
		
		[parameter(Mandatory = $true)]
        [System.String]
        $Type,

		[parameter(Mandatory = $true)]
        [System.String]
        $Identity,
		
        [System.String]
        $PIDataArchive = "localhost"
    )

    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
	if ($Type -eq "PIDatabaseSecurity")
	{
		$PIResource = Get-PIDatabasesecurity -Connection $Connection -Name $Name `
                | Select-Object -ExpandProperty security `
                | Where-Object { $_.Identity -eq $Identity } `
                | Select-Object -ExpandProperty Access
    }
	else
	{
        $Attribute = Get-PIPoint -Connection $Connection -Name $Name -Attributes $Type | Select-Object -ExpandProperty Attributes
        $AccessEntries = $Attribute[$Type].Split("|").Trim()
		Foreach ($entry in $AccessEntries)
		{
			if($entry -like "$($Identity):*")
			{
				$entry = $entry.Split(":").Trim()
				switch($entry)
				{
					"A(r)" { $Access = "Read" }
					"A(w)" { $Access = "Write" }
					"A(r,w)" { $Access = "Read, Write"}
					"A()" { $Access = ""}
				} 
				break
			}
		}
	}
	$Ensure = Get-PIResource_Ensure -PIResource $PIResource -Verbose:$VerbosePreference

    return @{
                Access = $PIResource
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
        $Ensure,
		
        [System.String]
        $PIDataArchive = "localhost"
    )

    $Connection = Connect-PIDataArchive -PIDataArchiveMachineName $PIDataArchive
    
    if($Ensure -eq 'Absent')
    { 
    }
    else
    { 
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
        $Ensure,
		
        [System.String]
        $PIDataArchive = "localhost"
    )

    $PIResource = Get-TargetResource -Name $Name -Type $Type -PIDataArchive $PIDataArchive

    if($PIResource.Ensure -eq 'Present' -and $Ensure -eq 'Present')
    {
    
    }
    else
    {
        
    }
}

Export-ModuleMember -Function *-TargetResource
