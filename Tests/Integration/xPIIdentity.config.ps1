$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            Name = "IntegrationIdentity"
            AllowUseInMappings = $true
        }
    )
}

Configuration xPIIdentity_Set
{
    param(
        [System.Boolean] $AllowUseInTrusts,
        [System.Boolean] $CanDelete,
        [System.String] $Description,
        [System.Boolean] $IsEnabled
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIIdentity xPIIdentity_SetIntegration
        {
            Name = $Node.Name
            AllowUseInMappings = $Node.AllowInMappings
            AllowUseInTrusts = $AllowUseInTrusts
            CanDelete = $CanDelete
            Description = $Description
            Ensure = "Present"
            IsEnabled = $IsEnabled
            PIDataArchive = $Node.NodeName
        } 
    }
}

Configuration xPIIdentity_Remove
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIIdentity xPIIdentity_RemoveIntegration
        {
            Name = $Node.Name
            Ensure = "Absent"
            PIDataArchive = $Node.NodeName
        } 
    }
}