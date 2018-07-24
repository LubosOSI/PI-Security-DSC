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
    [cmdletbinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AFServer,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ElementPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $getTargetResourceResult = $null
    $ensureResult = $null
    $attributeName = $null
    [string[]]$attributeValue = $null
    $attributeType = $null
    $attributeIsArray = $null

    $attribute = Get-AFAttributeDSC -AFServer $AFServer -ElementPath $ElementPath -Name $Name

    if($null -eq $attribute)
    {
        $ensureResult = 'Absent'
    }
    else
    {
        $ensureResult = 'Present'
        $attributeName = $attribute.Name
        $attributeValue = Get-AFAttributeValueDSC -Attribute $attribute
        $attributeType = $attribute.Type.Name -replace '\[\]', ''
        $attributeIsArray = $attribute.Type.Name.EndsWith('[]')
    }

    Write-Verbose "GetResult: Name: $Name"
    Write-Verbose "GetResult: ElementPath: $ElementPath"
    Write-Verbose "GetResult: EnsureResult: $ensureResult"
    Write-Verbose "GetResult: Value: $attributeValue"
    Write-Verbose "GetResult: Type: $attributeType"
    Write-Verbose "GetResult: IsArray: $attributeIsArray"

    $getTargetResourceResult = @{
                                    AFServer = $AFServer;
                                    Name = $attributeName;
                                    Ensure = $ensureResult;
                                    ElementPath = $ElementPath;
                                    Value = $attributeValue;
                                    Type = $attributeType;
                                    IsArray = $attributeIsArray;
                                }
    return $getTargetResourceResult
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AFServer,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ElementPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string[]]$Value,

        [ValidateSet("Boolean", "Byte", "DateTime", "Double", "Int16", "Int32", "Int64", "Single", "String")]
        [string]$Type = "String",

        [boolean]$IsArray = $false
    )

    $PIResource = Get-TargetResource -Ensure $Ensure -ElementPath $ElementPath -Name $Name -AFServer $AFServer

    if($PIResource.Ensure -eq 'Absent')
    {
        
        if($Ensure -eq 'Absent')
        { 
            Write-Verbose "Attribute '$Name' not found in Element"
            return
        }
        else
        {
            Write-Verbose "Adding attribute Name: '$Name' Value: $Value"
            Add-AFAttributeDSC -AFServer $AFServer -ElementPath $ElementPath -Name $Name -Type $Type -IsArray $IsArray -Value $Value
        }
    }
    else
    {
        if($Ensure -eq 'Absent')
        {
            Write-Verbose "Removing AFAttribute: '$Name'"
            Remove-AFAttributeDSC -AFServer $AFServer -ElementPath $ElementPath -Name $Name
        }
        else
        {
            Write-Verbose "Setting AFAttribute: '$Name'"
            Set-AFAttributeDSC -AFServer $AFServer -ElementPath $ElementPath -Name $Name -Type $Type -IsArray $IsArray -Value $Value 
        }
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AFServer,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ElementPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string[]]$Value,

        [ValidateSet("Boolean", "Byte", "DateTime", "Double", "Int16", "Int32", "Int64", "Single", "String")]
        [string]$Type = "String",

        [boolean]$IsArray = $false
    )

    Write-Verbose "Testing AFAttribute: '$Name'"
    $result = Get-TargetResource -Ensure $Ensure -ElementPath $ElementPath -Name $Name -AFServer $AFServer
    $ensureMatch = $result.Ensure -eq $Ensure
    # Return true without further processing if absent.
    if($ensureMatch -and $Ensure -eq "Absent")
    {
        return $true
    }
    $typeMatch = $result.Type -eq $Type
    $arrayMatch = $result.IsArray -eq $IsArray
    if($result.IsArray)
    {
        # Array equality check is a pain, here's the workaround
        if($result.Value.Count -ne $Value.Count)
        {
            $valueMatch = $false
        }
        else
        {
            $valueMatch = $true
            for($i=0; $i -lt $result.Value.Count; $i++)
            {
                if([string]$result.Value[$i] -ne $Value[$i]) { $valueMatch = $false; break }
            }
        }
    }
    else
    {
        $valueMatch = [string]$result.Value -eq $Value
    }

    Write-Verbose "TestResult: Ensure: $ensureMatch"
    Write-Verbose "TestResult: Value: $valueMatch"
    Write-Verbose "TestResult: Type: $typeMatch"
    Write-Verbose "TestResult: IsArray: $arrayMatch"

    if($ensureMatch -and $valueMatch -and $typeMatch -and $arrayMatch)
    {
        $true
    }
    else
    {
        $false
    }
}

function Get-AFElementDSC
{
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AFServer,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ElementPath
    )
    $ElementPath = ConvertTo-FullAFPath -AFServer $AFServer -ElementPath $ElementPath
    $loaded = [System.Reflection.Assembly]::LoadWithPartialName("OSIsoft.AFSDK")
    if ($null -eq $loaded) {
        $ErrorActionPreference = 'Stop'
        throw "AF SDK could not be loaded"
    }

    $tempList = New-Object "System.Collections.Generic.List[string]"
    $tempList.Add($ElementPath) | Out-Null

    # This method returns a collection, must find specific element using key of the path
    $element = [OSIsoft.AF.Asset.AFElement]::FindElementsByPath($tempList, $null)[$ElementPath]
    if($null -eq $element)
    {
        $ErrorActionPreference = 'Stop'
        throw "Could not locate AF Element at path $ElementPath"
    }
    return $element
}

function Get-AFAttributeDSC
{
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AFServer,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ElementPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    $element = Get-AFElementDSC -AFServer $AFServer -ElementPath $ElementPath
    $attribute = $element.Attributes | Where-Object Name -EQ $Name
    
    return $attribute
}

function Get-AFAttributeValueDSC
{
    param(
        [object]$Attribute
    )
    $Attribute.GetValue().Value
}

function Set-AFAttributeDSC
{
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AFServer,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ElementPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string[]]$Value,

        [ValidateSet("Boolean", "Byte", "DateTime", "Double", "Int16", "Int32", "Int64", "Single", "String")]
        [string]$Type = "String",

        [boolean]$IsArray = $false
    )
    $element = Get-AFElementDSC -AFServer $AFServer -ElementPath $ElementPath
    $attribute = Get-AFAttributeDSC -AFServer $AFServer -ElementPath $ElementPath -Name $Name
    $typeMatch = $attribute.Type -eq (ConvertFrom-TypeString -TypeName $Type -IsArray $IsArray)
    if(-not $typeMatch)
    {
        Write-Verbose "Setting type to $Type$(if($IsArray){'[]'})"
        $attribute.Type = ConvertFrom-TypeString -TypeName $Type -IsArray $IsArray
    }
    if($IsArray)
    {
        # Array equality check is a pain, here's the workaround
        if($Attribute.Value.Count -ne $Value.Count)
        {
            $valueMatch = $false
        }
        else
        {
            $valueMatch = $true
            for($i=0; $i -lt $Attribute.Value.Count; $i++)
            {
                if(([string]$attribute.Value[$i]) -ne $Value[$i]) { $valueMatch = $false }
            }
        }
        if(-not $valueMatch)
        {
            Write-Verbose "Setting value to $($Value -join ',')"
            $attribute.SetValue($Value)
            $element.CheckIn()
        }
    }
    else
    {
        Write-Verbose "Setting value to $($Value[0])"
        $attribute.SetValue($Value[0])
        $element.CheckIn()
    }    
}

function Add-AFAttributeDSC
{
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AFServer,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ElementPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string[]]$Value,

        [ValidateSet("Boolean", "Byte", "DateTime", "Double", "Int16", "Int32", "Int64", "Single", "String")]
        [string]$Type = "String",

        [boolean]$IsArray = $false
    )
    $element = Get-AFElementDSC -AFServer $AFServer -ElementPath $ElementPath
    $attribute = $element.Attributes.Add($Name)
    $attribute.Type = ConvertFrom-TypeString -TypeName $Type -IsArray $IsArray
    if($IsArray)
    {
        $attribute.SetValue($Value) # writes array
    }
    else
    {
        $attribute.SetValue($Value[0])
    }
    $element.CheckIn()
}

function Remove-AFAttributeDSC
{
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AFServer,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ElementPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    $element = Get-AFElementDSC -AFServer $AFServer -ElementPath $ElementPath
    $element.Attributes.Remove($Name) | Out-Null
    $element.CheckIn()
}

function ConvertFrom-TypeString
{
    [cmdletbinding()]
    param
    (
        [ValidateSet("Boolean", "Byte", "DateTime", "Double", "Int16", "Int32", "Int64", "Single", "String")]
        [string]$TypeName,

        [boolean]$IsArray
    )

    if($IsArray)
    {
        switch($TypeName)
        {
            "Boolean" {[System.Boolean[]]; break}
            "Byte" {[System.Byte[]]; break}
            "DateTime" {[System.DateTime[]]; break}
            "Double" {[System.Double[]]; break}
            "Int16" {[System.Int16[]]; break}
            "Int32" {[System.Int32[]]; break}
            "Int64" {[System.Int64[]]; break}
            "Single" {[System.Single[]]; break}
            "String" {[System.String[]]; break}
        }
    }
    else
    {
        switch($TypeName)
        {
            "Boolean" {[System.Boolean]; break}
            "Byte" {[System.Byte]; break}
            "DateTime" {[System.DateTime]; break}
            "Double" {[System.Double]; break}
            "Int16" {[System.Int16]; break}
            "Int32" {[System.Int32]; break}
            "Int64" {[System.Int64]; break}
            "Single" {[System.Single]; break}
            "String" {[System.String]; break}
        }
    }
}

Export-ModuleMember -Function *-TargetResource