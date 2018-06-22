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

Import-Module 'PSScriptAnalyzer'

$targetFileTypes = @(
                       '*.psm1',
                       '*.ps1' 
                    )
$scriptPath = GetScriptPath
$targetFiles = Get-ChildItem -Path (Split-Path ($scriptPath)) -Recurse -File -Include $targetFileTypes
Write-Host "Found $($targetFiles.Count) files for analysis."
$resultsFolderName = 'Results'
$resultsFolder = Join-Path -Path $scriptPath -ChildPath $resultsFolderName

if(!(Test-Path -Path $resultsFolder))
{ New-Item -Path $resultsFolder -ItemType Directory -Name $resultsFolderName }

# Define set of rules to exclude from the analysis, globally.
$excludedRules = @( 'PSUseShouldProcessForStateChangingFunctions' )

foreach ($targetFile in $targetFiles) 
{
    $resultsFile = $(Join-Path -Path $resultsFolder -ChildPath ($targetFile.Name + '.staticanalysis.dat'))
    Write-Host "Analyzing $($targetFile.Name)"
	Invoke-ScriptAnalyzer -Path $targetFile.FullName -ExcludeRule $excludedRules -ErrorAction SilentlyContinue | Out-File $resultsFile -Force
}