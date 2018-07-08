$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            Identity = "IntegrationTemp"
            Database = "ExampleDatabase"
        }
    )
}

Configuration xAFAccessControl_GrantAccess
{
    param(
        [System.String] $Access = "Read, Read Data",
        [System.String] $Collection = "Default"
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        AFIdentity CreateIntegrationTempIdentity
        {
            Name = $Node.Identity
            AFServer = $Node.NodeName
            Ensure = "Present"
        }

        AFAccessControl GrantAccess_DatabaseItem
		{
		    AFServer = $Node.NodeName
            Path = "$($Node.Database)\$Collection"
            Identity = $Node.Identity
            Type = "AFSecurityItem"
            Access = $Access
            Ensure = "Present"
            DependsOn = "[AFIdentity]CreateIntegrationTempIdentity"
	    }

        AFAccessControl GrantAccess_ServerItem
		{
		    AFServer = $Node.NodeName
            Path = $Collection
            Identity = $Node.Identity
            Type = "AFSecurityItem"
            Access = $Access
            Ensure = "Present"
            DependsOn = "[AFIdentity]CreateIntegrationTempIdentity"
	    }

        AFAccessControl GrantAccess_Element
		{
		    AFServer = $Node.NodeName
            Path = "$($Node.Database)\IntegrationTarget"
            Identity = $Node.Identity
            Type = "AFElement"
            Access = $Access
            Ensure = "Present"
            DependsOn = "[AFIdentity]CreateIntegrationTempIdentity"
	    }
    }
}

Configuration xAFAccessControl_RevokeAccess
{
    param(
        [System.String] $NodeName = "localhost",
        [System.String] $Collection = "Default"
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node $NodeName
    {
        AFAccessControl RevokeAccess_Database
		{
		    AFServer = $Node.NodeName
            Path = "$($Node.Database)\$Collection"
            Identity = $Node.Identity
            Type = "AFSecurityItem"
            Ensure = "Absent"
	    }

        AFAccessControl RevokeAccess_Server
		{
		    AFServer = $Node.NodeName
            Path = $Collection
            Identity = $Node.Identity
            Type = "AFSecurityItem"
            Ensure = "Absent"
	    }

        AFAccessControl RevokeAccess_Element
		{
		    AFServer = $Node.NodeName
            Path = "$($Node.Database)\IntegrationTarget"
            Identity = $Node.Identity
            Type = "AFElement"
            Ensure = "Absent"
	    }
    }
}

Configuration xAFAccessControl_CleanUpAccessTest
{
    param(
        [System.String] $NodeName = "localhost"
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node $NodeName
    {
        AFIdentity RemoveIntegrationTempIdentity
        {
            Name = $Node.Identity
            AFServer = $Node.NodeName
            Ensure = "Absent"
        }
    }
}