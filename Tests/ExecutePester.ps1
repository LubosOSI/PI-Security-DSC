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

#region - Help

<#
.SYNOPSIS
Execute Pester tests.

.DESCRIPTION
Execute Pester tests.

.PARAMETER TestNameFilter
Set a test name filter.

.PARAMETER TagList
Set a list of tags corresponding to tests to execute.

.EXAMPLE
.\ExecutePester.ps1

.EXAMPLE
$tl = @('RightSyntax','WrongSyntax')
.\ExecutePester.ps1 -TagList $tl

.EXAMPLE
.\ExecutePester.ps1 -TestNameFilter 'Get-TargetResource'
#>

#endregion

#region - Parameters declaration.
[CmdletBinding()]
param(
		[parameter(Mandatory = $false)]
		[String]
		$TestNameFilter = '*',

		[parameter(Mandatory = $false)]
		[String[]]
		$TagList = @()
)

#endregion

#region - Internal Helper Functions

function GetScriptPath
{
	$scriptFolder = (Get-Variable 'PSScriptRoot' -ErrorAction 'SilentlyContinue').Value
	if(!$scriptFolder)
	{
		if($MyInvocation.MyCommand.Path)
		{
			$scriptFolder = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
		}
	}
	if(!$scriptFolder)
	{
		if ($ExecutionContext.SessionState.Module.Path)
		{
			$scriptFolder = Split-Path (Split-Path $ExecutionContext.SessionState.Module.Path)
		}
	}

	# Return path.
	return $scriptFolder
}

#endregion

#region - Main routine

try
{
	# Define paths.
	$rootFolder = GetScriptPath
    $unitTestFolder = Join-Path -Path $rootFolder -ChildPath 'Unit'

	# Import the Pester module.
	try
    {
	    # Get module.
	    $modulesObj = Get-Module | Where-Object { $_.Name -match '^pester$' }

	    # Set flags.
	    $notLoaded = ($modulesObj.Count -eq 0)
	    $multipleLoaded = ($modulesObj.Count -gt 1)

	    if($multipleLoaded)
	    {
		    $msg = "Multiple instances of 'Pester' have been detected"
		    Throw $msg
	    }
	    elseif($notLoaded)
	    { Import-Module 'Pester' -Force }

    }
    catch
    { Throw }

	# Show message at console.
	if($TagList.Count -eq 0)
	{ $msg = 'Execute all tests found with *.tests.ps1 extension' }
	else
	{ $msg = 'Execute tests matching theses tags: {0} and found with *.tests.ps1 extension' -f ($TagList -Join ', ')}
	Write-Host $msg -ForegroundColor 'Yellow'

	# https://github.com/pester/Pester/wiki/Invoke-Pester
	Invoke-Pester -Script $($unitTestFolder + '\*.tests.ps1') -Tag $TagList -TestName $TestNameFilter
}
catch
{ Throw }

#endregion