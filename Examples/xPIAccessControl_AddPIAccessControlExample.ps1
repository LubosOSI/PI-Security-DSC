Configuration AddPIAccessControlExample
{
	Import-DscResource -Module PISecurityDSC

	Node localhost
	{
		PIAccessControl PIAccessControl_PIReplication_PIWorld
		{
			Name = "PIReplication"
            Identity = "PIWorld"
            Type = "PIDatabaseSecurity"
            Access = "Read"
            Ensure = "Present"
		}
	}
}