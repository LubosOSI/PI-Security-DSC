Configuration AddAFAccessControlExample
{
    param(
        [System.String] $NodeName = "localhost",
        [System.String] $Database = "ExampleDatabase",
        [System.String] $RelayIdentity = "PIConnectorRelay",
        [System.String] $DCMIdentity   = "PIDataCollectionManager"
    )

	Import-DscResource -Module PISecurityDSC
    
	Node $NodeName
	{

        AFIdentity "AFIdentity_$RelayIdentity"
        {
            Name = $RelayIdentity
            AFServer = $NodeName
            Ensure = "Present"
        }

        AFIdentity "AFIdentity_$DCMIdentity"
        {
            Name = $DCMIdentity
            AFServer = $NodeName
            Ensure = "Present"
        }
        
        $Collections = @(
            'Elements',
            'Element Templates',
            'Enumeration Sets',
            'Event Frames'
        )

        foreach($Collection in $Collections)
        {
		    AFAccessControl "AFAccessControl_$RelayIdentity($Database\$Collection)"
		    {
			    AFServer = $NodeName
                Path = "$Database\$Collection"
                Identity = $RelayIdentity
                Type = "AFSecurityItem"
                Access = "Read, Write, Read Data, Write Data"
                Ensure = "Present"
                DependsOn = "[AFIdentity]AFIdentity_$RelayIdentity"
		    }
        }
        
        AFAccessControl "AFAccessControl_$DCMIdentity"
		{
			AFServer = $NodeName
            Path = "SecurityIdentity"
            Identity = $DCMIdentity
            Type = "AFSecurityItem"
            Access = "Read, Read Data"
            Ensure = "Present"
            DependsOn = "[AFIdentity]AFIdentity_$DCMIdentity"
		}
	}
}