$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            Name = "Sinusoid"
        }
    )
}

Configuration xPIPoint_Set
{
    param(
        [System.String] $DataSecurity,
        [System.String] $PtSecurity
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIPoint xPIPoint_SetIntegration
        {
            Name = $Node.Name
            DataSecurity = $DataSecurity
            Ensure = "Present"
            PIDataArchive = $Node.NodeName
            PtSecurity = $PtSecurity
        } 
    }
}

Configuration xPIPoint_Remove
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIPoint xPIPoint_RemoveIntegration
        {
            Name = $Node.Name
            Ensure = "Absent"
            PIDataArchive = $Node.NodeName
        }
    }
}