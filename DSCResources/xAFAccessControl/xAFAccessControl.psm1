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
        [ValidateSet('AFSecurityItem','AFElement')]
        [parameter(Mandatory = $true)]
        [System.String]
        $Type,

        [parameter(Mandatory = $true)]
        [System.String]
        $AFServer,

        [parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [ValidateSet('Allow','Deny')]
        [parameter(Mandatory = $true)]
        [System.String]
        $Action,

        [parameter(Mandatory = $true)]
        [System.String]
        $Identity
    )

    $AF = Connect-AFServerUsingSDK -AFServer $AFServer
    
    $AFSecurityObject = Get-AFSecurityObject -Type $Type -Path $Path -AFServer $AFServer

    $Access = $AFSecurityObject.GetSecurityEntries() | Where-Object { $_.Name -eq $Identity } | Select-Object -ExpandProperty Rights
    
    if([System.String]::IsNullOrEmpty($Access))
    {
        $Access = "None"
        $Ensure = "Absent"
    }
    else
    {
        $Ensure = "Present"
    }
    Write-Verbose "Access for $Identity on $Type\$Path is $Ensure ($Access)"

    $returnValue = @{
        Ensure = $Ensure
        Type = $Type
        AFServer = $AFServer
        Path = $Path
        Identity = $Identity
        Access = $Access
    }

    $returnValue
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [ValidateSet('AFSecurityItem','AFElement')]
        [parameter(Mandatory = $true)]
        [System.String]
        $Type,

        [parameter(Mandatory = $true)]
        [System.String]
        $AFServer,

        [parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [parameter(Mandatory = $true)]
        [System.String]
        $Identity,

        [System.String]
        $Access,

        [ValidateSet("Allow","Deny")]
        [System.String]
        $Action = "Allow"
    )

    if(!$(Test-TargetResource -Ensure $Ensure -Type $Type -AFServer $AFServer -Path $Path -Identity $Identity -Access $Access -Action $Action -Verbose:$VerbosePreference))
    {
        $AF = Connect-AFServerUsingSDK -AFServer $AFServer

        $PISystem = $AF.PISystem
        $AFSecurityIdentity = $PISystem.SecurityIdentities[$Identity]
        $AFSecurityObject = Get-AFSecurityObject -Type $Type -Path $Path -AFServer $AFServer
        $TargetItems = New-Object System.Collections.Generic.List["OSIsoft.AF.AFSecurity"]
        $TargetItems.Add($AFSecurityObject) | Out-Null
        $ApplyToChildren = $false

        if($Ensure -eq "Absent")
        {
            Write-Verbose "Removing access for $Identity"
            [OSIsoft.AF.AFSecurity]::RemoveIdentity($PISystem, $AFSecurityIdentity, $TargetItems, $ApplyToChildren)
        }
        else
        {
            Write-Verbose "Updating access for $Identity"
            $SpecifiedRights = ConvertTo-CanonicalAFSecurityRight -Access $Access
            $Operation = [OSIsoft.AF.AFSecurityOperation]::Replace
            if($Action -eq "Allow")
            {
                Write-Verbose "Updating access to allow: $SpecifiedRights"
                $RightsToAllow = $SpecifiedRights
                $RightsToDeny = [OSIsoft.AF.AFSecurityRights]::None
            }
            else
            {
                Write-Verbose "Updating access to deny: $SpecifiedRights"
                $RightsToAllow = [OSIsoft.AF.AFSecurityRights]::None
                $RightsToDeny = $SpecifiedRights
            }
            [OSIsoft.AF.AFSecurity]::AddIdentity($PISystem, $AFSecurityIdentity, $TargetItems, $RightsToAllow, $RightsToDeny, $Operation, $ApplyToChildren)
        }
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [ValidateSet('AFSecurityItem','AFElement')]
        [parameter(Mandatory = $true)]
        [System.String]
        $Type,

        [parameter(Mandatory = $true)]
        [System.String]
        $AFServer,

        [parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [parameter(Mandatory = $true)]
        [System.String]
        $Identity,

        [System.String]
        $Access,

        [ValidateSet("Allow","Deny")]
        [System.String]
        $Action = "Allow"
    )

    $PIResource = Get-TargetResource -Action $Action -Type $Type -AFServer $AFServer -Path $Path -Identity $Identity -Verbose:$VerbosePreference
    $CurrentAccess = ConvertTo-CanonicalAFSecurityRight $PIResource.Access
    $DesiredAccess = ConvertTo-CanonicalAFSecurityRight $Access
    
    return $CurrentAccess -eq $DesiredAccess -and $PIResource.Ensure -eq $Ensure
}

function Get-AFSecurityObject
{
    param(
            [ValidateSet('AFSecurityItem','AFElement')]
            [parameter(Mandatory = $true)]
            [System.String]
            $Type,

            [parameter(Mandatory = $true)]
            [System.String]
            $AFServer,

            [parameter(Mandatory = $true)]
            [System.String]
            $Path
    )

    $AF = Connect-AFServerUsingSDK $AFServer

    if($Type -eq "AFSecurityItem")
    {
        # A slash indicates "Database\Collection"
        if($Path.IndexOf('\') -ne -1)
        {
            $Tokens = $Path.Split('\')
            $Database = $Tokens[0]
            $Name = $Tokens[1]
            $AFObject = $AF.Databases[$Database]
        }
        else
        {
            $Name = $Path
            $AFObject = $AF
        }

        $Name = ConvertTo-CanonicalAFSecurityItem $Name
        $AFSecurityObject = $AFObject.GetSecurity($Name)
    }
    elseif($Type -eq "AFElement")
    {
        $ElementPath = ConvertTo-FullAFPath -AFServer $AFServer -ElementPath $Path
        $tempList = New-Object "System.Collections.Generic.List[string]"
        $tempList.Add($ElementPath) | Out-Null

        # This method returns a collection, must find specific element using key of the path
        $AFObject = [OSIsoft.AF.Asset.AFElement]::FindElementsByPath($tempList, $null)[$ElementPath]

        $AFSecurityObject = $AFObject.Security
    }

    return $AFSecurityObject
}

function ConvertTo-CanonicalAFSecurityItem
{
    param(
        [parameter(Mandatory=$true)]
        [string]
        $AFSecurityItem
    )

    $AFSecurityItemMapping = @{
        "Databases"                      = "Database"
        "EventFrames"                    = "EventFrame"
        "Event Frames"                   = "EventFrame"
        "Elements"                       = "Element"
        "ElementTemplates"               = "ElementTemplate"
        "Element Templates"              = "ElementTemplate"
        "Analyses"                       = "Analysis"
        "Tables"                         = "Table"
        "Transfers"                      = "Transfer"
        "ReferenceTypes"                 = "ReferenceType"
        "Reference Types"                = "ReferenceType"
        "EnumerationSets"                = "EnumerationSet"
        "Enumeration Sets"               = "EnumerationSet"
        "Contacts"                       = "Contact"
        "Notifications"                  = "Notification"
        "NotificationContactTemplates"   = "NotificationContactTemplate"
        "Notification Contact Templates" = "NotificationContactTemplate"
        "AnalysisTemplates"              = "AnalysisTemplate"
        "Analysis Templates"             = "AnalysisTemplate"
        "Categories"                     = "Category"
        "SecurityIdentities"             = "SecurityIdentity"
        "Security Identities"            = "SecurityIdentity"
        "Identities"                     = "SecurityIdentity"
        "SecurityMappings"               = "SecurityMapping"
        "Security Mappings"              = "SecurityMapping"
        "Mappings"                       = "SecurityMapping"
        "NotificationRuleTemplates"      = "NotificationRuleTemplate"
        "Notification Rule Templates"    = "NotificationRuleTemplate"
        "NotificationRules"              = "NotificationRule"
        "Notification Rules"             = "NotificationRule"
        "TableConnections"               = "TableConnection"
        "Table Connections"              = "TableConnection"
    }

    if($AFSecurityItem -in [System.Enum]::GetNames([OSIsoft.AF.AFSecurityItem]))
    {
        $CanonicalAFSecurityItem = $AFSecurityItem
    }
    elseif($AFSecurityItemMapping.ContainsKey($AFSecurityItem))
    {
        $CanonicalAFSecurityItem = $AFSecurityItemMapping[$AFSecurityItem]
    }
    else
    {
        throw "Invalid AFSecurityItem specified: $AFSecurityItem"
    }

    return $CanonicalAFSecurityItem
}

function ConvertTo-CanonicalAFSecurityRight
{
    param(
            [Parameter(Mandatory)]
            [string]
            $Access
         )

    $AFSecurityRightMapping = @{
        "Write Data"       = "WriteData"
        "Read Data"        = "ReadData"
        "Read/Write"       = "ReadWrite"
        "Read/Write Data"  = "ReadWriteData"
        "Subscribe Others" = "SubscribeOthers"
        "r"                = "Read"
        "w"                = "Write"
        "rd"               = "ReadData"
        "wd"               = "WriteData"
        "d"                = "Delete"
        "x"                = "Execute"
        "a"                = "Admin"
        "s"                = "Subscribe"
        "so"               = "SubscribeOthers"
        "an"               = "Annotate"
    }

    if([System.String]::IsNullOrEmpty($Access))
    {
        $CanonicalAFSecurityRight = [OSIsoft.AF.AFSecurityRights]::None   
    }
    else
    {
        $AFSecurityRightArray = @()
        $AFSecurityRightArray = $Access.Split(',').Trim()
        $CanonicalAFSecurityRight = [OSIsoft.AF.AFSecurityRights]::None
        foreach($AFSecurityRight in $AFSecurityRightArray)
        {
            if($AFSecurityRight -in [System.Enum]::GetNames([OSIsoft.AF.AFSecurityRights]))
            {
                $CanonicalAFSecurityRight += [OSIsoft.AF.AFSecurityRights]::$AFSecurityRight
            }
            elseif($AFSecurityRightMapping.ContainsKey($AFSecurityRight))
            {
                $CanonicalAFSecurityRight += [OSIsoft.AF.AFSecurityRights]::($AFSecurityRightMapping[$AFSecurityRight])
            }
            else
            {
                throw "Invalid AFSecurityRight specified: $AFSecurityRight"
            }
        }
    }

    return $CanonicalAFSecurityRight
}

Export-ModuleMember -Function *-TargetResource