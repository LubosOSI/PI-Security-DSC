$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            Name = "IntegrationTemp"
            ElementPath = "ExampleDatabase\IntegrationTarget"
        }
    )
}

Configuration xAFAttribute_Set
{
    param(
        [System.String] $NumericValue,
        [System.String] $BooleanValue,
        [System.String] $DateTimeValue
    )

    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        $TestValues = @(
                    @{
                        Type = "Boolean"
                        Value = $BooleanValue
                    },
                    @{
                        Type = "Byte"
                        Value = $NumericValue
                    },
                    @{
                        Type = "DateTime"
                        Value = $DateTimeValue
                    },
                    @{
                        Type = "Double"
                        Value = $NumericValue
                    },
                    @{
                        Type = "Int16"
                        Value = $NumericValue
                    },
                    @{
                        Type = "Int32"
                        Value = $NumericValue
                    },
                    @{
                        Type = "Int64"
                        Value = $NumericValue
                    },
                    @{
                        Type = "Single"
                        Value = $NumericValue
                    }
                    @{
                        Type = "String"
                        Value = $NumericValue
                    }
        )
        foreach($TestValue in $TestValues)
        { 
            $AttributeName = $Node.Name + "_" + $TestValue["Type"]
            AFAttribute "Set_$AttributeName"
            {
                AFServer = $Node.NodeName
                Name = $AttributeName
                ElementPath = $Node.ElementPath
                Ensure = "Present"
                Value = $TestValue["Value"]
                Type = $TestValue["Type"]
                IsArray = $false
            }
            $AttributeName += "(Array)"
            AFAttribute "Set_$AttributeName"
            {
                AFServer = $Node.NodeName
                Name = $AttributeName
                ElementPath = $Node.ElementPath
                Ensure = "Present"
                Value = @($TestValue["Value"],$TestValue["Value"])
                Type = $TestValue["Type"]
                IsArray = $true
            }
        }
    }
}

Configuration xAFAttribute_Remove
{
    param()
    Import-DscResource -ModuleName PISecurityDSC 
 
    Node localhost
    {
        $TestValues = @(
                    "Boolean",
                    "Byte",
                    "DateTime",
                    "Double",
                    "Int16",
                    "Int32",
                    "Int64",
                    "Single",
                    "String"
        )
        foreach($TestValue in $TestValues)
        { 
            $AttributeName = $Node.Name + $TestValue
            AFAttribute "Remove_$AttributeName"
            {
                AFServer = $Node.NodeName
                Name = $AttributeName
                ElementPath = $Node.ElementPath
                Ensure = "Absent"
            } 
            $AttributeName += "_Array"
            AFAttribute "Remove_$AttributeName"
            {
                AFServer = $Node.NodeName
                Name = $AttributeName
                ElementPath = $Node.ElementPath
                Ensure = "Absent"
            }
        }
    }
}