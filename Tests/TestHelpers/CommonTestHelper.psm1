function Initialize-TestEnvironment
{
    [OutputType([Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $DscModuleName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $DscResourceName
    )

    $moduleRootFilePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $dscResourcesFolderFilePath = Join-Path -Path $moduleRootFilePath -ChildPath "DSCResources"
    $dscResourceToTestFolderFilePath = Join-Path -Path $dscResourcesFolderFilePath -ChildPath $DscResourceName
    $moduleFilePath = Join-Path -Path $dscResourceToTestFolderFilePath -ChildPath "$DscResourceName.psm1"
    
    Import-Module -Name $moduleFilePath -Scope 'Global' -Force

    $oldExecutionPolicy = Get-ExecutionPolicy
    if ($oldExecutionPolicy -ine 'Unrestricted')
    {
        Set-ExecutionPolicy -ExecutionPolicy 'Unrestricted' -Scope 'Process' -Force
    }

    return @{
        DSCModuleName = $DscModuleName
        DSCResourceName = $DscResourceName
        ImportedModulePath = $moduleFilePath
        OldExecutionPolicy = $oldExecutionPolicy
    }
}

function Restore-TestEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $TestEnvironment
    )

    if ($TestEnvironment.OldExecutionPolicy -ne (Get-ExecutionPolicy))
    {
        Set-ExecutionPolicy -ExecutionPolicy $TestEnvironment.OldExecutionPolicy -Scope 'Process' -Force
    }
}