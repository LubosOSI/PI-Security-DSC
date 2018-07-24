$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            Name = "PIAudit"
        }
    )
}

Configuration xPIDatabaseSecurity_Set
{
    param(
        [System.String] $Security
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIDatabaseSecurity xPIDatabaseSecurity_SetIntegration
        {
            Name = $Node.Name
            Security = $Security
            Ensure = "Present"
            PIDataArchive = $Node.NodeName
        } 
    }
}

Configuration xPIDatabaseSecurity_Remove
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIDatabaseSecurity xPIDatabaseSecurity_RemoveIntegration
        {
            Name = $Node.Name
            Ensure = "Absent"
            PIDataArchive = $Node.NodeName
        }
    }
}