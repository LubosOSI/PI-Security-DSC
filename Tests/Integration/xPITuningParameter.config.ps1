$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            Name = "Archive_MaxQueryExecutionSec"
        }
    )
}

Configuration xPITuningParameter_Set
{
    param(
        [System.String] $Value
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PITuningParameter xPITuningParameter_SetIntegration
        {
            Name = $Node.Name
            Ensure = "Present"
            PIDataArchive = $Node.NodeName
            Value = $Value
        } 
    }
}

Configuration xPITuningParameter_Remove
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        PIIdentity xPITuningParameter_RemoveIntegration
        {
            Name = $Node.Name
            Ensure = "Absent"
            PIDataArchive = $Node.NodeName
        } 
    }
}