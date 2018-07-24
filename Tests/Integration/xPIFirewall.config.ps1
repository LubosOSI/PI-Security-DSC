$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            HostMask = "169.254.0.0"
        }
    )
}

Configuration xPIFirewall_Set
{
    param(
        [System.String] $Value
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIFirewall xPIFirewall_SetIntegration
        {
            Hostmask = $Node.Hostmask
            Ensure = "Present"
            PIDataArchive = $Node.NodeName
            Value = $Value
        } 
    }
}

Configuration xPIFirewall_Remove
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIFirewall xPIFirewall_RemoveIntegration
        {
            Hostmask = $Node.Hostmask
            Ensure = "Absent"
            PIDataArchive = $Node.NodeName
        }
    }
}