$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            Name = "TrustIntegration"
        }
    )
}

Configuration xPITrust_Set
{
    param(
        [System.String] $ApplicationName,
        [System.String] $Description,
        [System.Boolean] $Enabled,
        [System.String] $Identity,
        [System.String] $IPAddress,
        [System.String] $NetMask,
        [System.String] $NetworkPath,
        [System.String] $WindowsAccount,
        [System.String] $WindowsDomain
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIIdentity $Node.Name
        {
            Name = $Node.Name
            AllowUseInTrusts = $true
            CanDelete = $true
            Ensure = "Present"
            IsEnabled = $true
            PIDataArchive = $Node.NodeName
        }

        PITrust xPITrust_SetIntegration
        {
            Name = $Node.Name
            ApplicationName = $ApplicationName
            Description = $Description
            Enabled = $Enabled
            Ensure = "Present"
            Identity = $Node.Name
            IPAddress = $IPAddress
            NetMask = $NetMask
            NetworkPath = $NetworkPath
            PIDataArchive = $Node.NodeName
            WindowsAccount = $WindowsAccount
            WindowsDomain = $WindowsDomain
            DependsOn = "[PIIdentity]$($Node.Name)"
        }
    }
}

Configuration xPITrust_Remove
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PITrust xPITrust_RemoveIntegration
        {
            Name = $Node.Name
            Ensure = "Absent"
            PIDataArchive = $Node.NodeName
        }
    }
}

Configuration xPITrust_CleanUp
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIIdentity $Node.Name
        {
            Name = $Node.Name
            Ensure = "Present"
            PIDataArchive = $Node.NodeName
        }
    }
}