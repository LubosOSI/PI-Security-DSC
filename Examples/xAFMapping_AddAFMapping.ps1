Configuration AddAFMappingExample
{
	Import-DscResource -Module PISecurityDSC

	Node localhost
	{
		AFMapping AFMapping_PIReaders
		{
			Name = "PIReader"
            Description = "Read-only user role."
            Account = "Domain\Domain Users"
            AFIdentityName = "PIReaders"
            Ensure = "Present"
            AFServer = "localhost"
		}
	}
}
