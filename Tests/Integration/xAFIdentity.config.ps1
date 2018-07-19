$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            Name = "IntegrationTemp"
        }
    )
}

Configuration xAFIdentity_Set
{
    param(
        [System.String] $Description,
        [System.Boolean] $IsEnabled
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        AFIdentity xAFIdentity_SetIntegration
        {
            AFServer = $Node.NodeName
            Name = $Node.Name
            Description = $Description
            Ensure = "Present"
            IsEnabled = $IsEnabled
        } 
    }
}

Configuration xAFIdentity_Remove
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        AFIdentity xAFIdentity_RemoveIntegration
        {
            AFServer = $Node.NodeName
            Name = $Node.Name
            Ensure = "Absent"
        }
    }
}