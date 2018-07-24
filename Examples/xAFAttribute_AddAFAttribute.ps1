Configuration AddAFAttributeExample
{
	Import-DscResource -Module PISecurityDSC

	Node localhost
	{
		AFAttribute AFAttribute_AuthenticationMethods
		{
			Name="AuthenticationMethods"
            ElementPath = "Configuration\OSIsoft\PI Web API\myPIWebAPI\System Configuration"
            IsArray = "True"
            Type="String"
            Value = @("Kerberos")
            Ensure = "Present"
            AFServer = "localhost"
		}
	}
}