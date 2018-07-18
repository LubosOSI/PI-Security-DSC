$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            Name = "IntegrationTempMapping"
            AFIdentityName = "IntegrationTempIdentity"
        }
    )
}

Configuration xAFMapping_Set
{
    param(
        [System.String] $Account,
        [System.String] $Description
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        AFIdentity $($Node.AFIdentityName)
        {
            AFServer = $Node.NodeName
            Name = $($Node.AFIdentityName)
            Ensure = "Present"
            IsEnabled = $true
        }

        AFMapping xAFMapping_SetIntegration
        {
            AFServer = $Node.NodeName
            Name = $Node.Name
            Account = "NT Authority\" + $Account
            AFIdentityName = $Node.AFIdentityName
            Description = $Description
            Ensure = "Present"
            DependsOn = "[AFIdentity]$($Node.AFIdentityName)"
        } 
    }
}

Configuration xAFMapping_Remove
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        AFMapping xAFMapping_RemoveIntegration
        {
            AFServer = $Node.NodeName
            Name = $Node.Name
            Ensure = "Absent"
        } 
    }
}

Configuration xAFMapping_CleanUp
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        AFIdentity $($Node.AFIdentityName)
        {
            AFServer = $Node.NodeName
            Name = $($Node.AFIdentityName)
            Ensure = "Absent"
        }
    }
}