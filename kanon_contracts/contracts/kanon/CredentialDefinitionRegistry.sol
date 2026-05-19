pragma solidity ^0.8.0;

contract CredentialDefinitionRegistry {
    
    //@dev Struct to store the credential definition details
    //@param schemaId The schema id of the credential definition
    //@param issuer The DID of the issuer
    struct CredentialDefinition {
        string schemaId;
        string issuer;
        string detailsJson;
    }

    //@dev Mapping to store the credential definitions
    mapping(string => CredentialDefinition) public credentialDefinitions;

    //@dev Function to register a credential definition
    //@param _credDefId The credential definition id
    //@param _schemaId The schema id of the credential definition
    //@param _issuer The DID of the issuer
    //@param _detailsJson The JSON string of the credential definition
    //@notice This function is used to register a credential definition
    function registerCredentialDefinition(
        string memory _credDefId,
        string memory _schemaId,
        string memory _issuer,
        string memory _detailsJson
    ) public {
        require(
            bytes(credentialDefinitions[_credDefId].schemaId).length == 0,
            "Credential Definition already exists"
        );
        credentialDefinitions[_credDefId] = CredentialDefinition(
            _schemaId,
            _issuer,
            _detailsJson
        );
    }

    //@dev Function to get a credential definition
    //@param _credDefId The credential definition id
    //@return schemaId The schema id of the credential definition
    //@return issuer The DID of the issuer
    //@return detailsJson The JSON string of the credential definition
    //@notice This function is used to get a credential definition
    function getCredentialDefinition(
        string memory _credDefId
    ) public view returns (string memory, string memory, string memory) {
        require(
            bytes(credentialDefinitions[_credDefId].schemaId).length != 0,
            "Credential Definition does not exist"
        );
        return (
            credentialDefinitions[_credDefId].schemaId,
            credentialDefinitions[_credDefId].issuer,
            credentialDefinitions[_credDefId].detailsJson
        );
    }
}
