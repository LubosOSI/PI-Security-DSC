$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            Identity = "PIWorld"
        }
    )
}

Configuration xPIAccessControl_Set
{
    param(
        [System.String] $DbName = "PIMSGSS",
        [System.String] $Access = "Read",
        [System.String] $PtName = "Sinusoid"
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIAccessControl xPIAccessControl_SetIntegrationDb
        {
            Identity = $Node.Identity
            Name = $DbName
            Type = "PIDatabaseSecurity"
            Access = $Access
            Ensure = "Present"
            PIDataArchive = $Node.NodeName
        } 

        PIAccessControl xPIAccessControl_SetIntegrationPt
        {
            Identity = $Node.Identity
            Name = $PtName
            Type = "DataSecurity"
            Access = $Access
            Ensure = "Present"
            PIDataArchive = $Node.NodeName
        }
    }
}

Configuration xPIAccessControl_Remove
{
    param(
        [System.String] $DbName = "PIMSGSS",
        [System.String] $PtName = "Sinusoid"
    )
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIAccessControl xPIAccessControl_RemoveIntegrationDb
        {
            Identity = $Node.Identity
            Name = $DbName
            Type = "PIDatabaseSecurity"
            Ensure = "Absent"
            PIDataArchive = $Node.NodeName
        }
        PIAccessControl xPIAccessControl_RemoveIntegrationPt
        {
            Identity = $Node.Identity
            Name = $PtName
            Type = "DataSecurity"
            Ensure = "Absent"
            PIDataArchive = $Node.NodeName
        }
    }
}