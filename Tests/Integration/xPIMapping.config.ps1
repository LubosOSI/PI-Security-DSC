$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PrincipalName = "BUILTIN\Guests"
            Identity = "IntegrationTempIdentity"
        }
    )
}

Configuration xPIMapping_Set
{
    param(
        [System.Boolean] $Enabled,
        [System.String] $Description
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIIdentity $($Node.Identity)
        {
            PIDataArchive = $Node.NodeName
            Name = $Node.Identity
            Ensure = "Present"
            IsEnabled = $true
        }

        PIMapping xPIMapping_SetIntegration
        {
            PIDataArchive = $Node.NodeName
            Name = $Node.Name
            PrincipalName = $Node.PrincipalName
            Identity = $Node.Identity
            Description = $Description
            Ensure = "Present"
            Enabled = $Enabled
            DependsOn = "[PIIdentity]$($Node.Identity)"
        } 
    }
}

Configuration xPIMapping_Remove
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIMapping xPIMapping_RemoveIntegration
        {
            PIDataArchive = $Node.NodeName
            PrincipalName = $Node.PrincipalName
            Ensure = "Absent"
        } 
    }
}

Configuration xPIMapping_CleanUp
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIIdentity $($Node.Identity)
        {
            PIDataArchive = $Node.NodeName
            Name = $($Node.Identity)
            Ensure = "Absent"
        }
    }
}