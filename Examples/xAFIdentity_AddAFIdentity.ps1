Configuration AddAFIdentityExample
{
	Import-DscResource -Module PISecurityDSC

	Node localhost
	{
		AFIdentity AFIdentity_PIReaders
		{
			Name = "PIReader"
            Description = "Read-only user role."
            IsEnabled = "True"
            Ensure = "Present"
            AFServer = "localhost"
		}
	}
}