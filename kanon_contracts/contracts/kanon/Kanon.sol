// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DIDRegistry.sol";
import "./SchemaRegistry.sol";
import "./CredentialDefinitionRegistry.sol";
import "./RevocationRegistry.sol";

contract Kanon {
    // @dev DIDRegistry contract
    DIDRegistry public didRegistry;
    // @dev SchemaRegistry contract
    SchemaRegistry public schemaRegistry;
    // @dev CredentialDefinitionRegistry contract
    CredentialDefinitionRegistry public credDefRegistry;
    // @dev RevocationRegistry contract
    RevocationRegistry public revocationRegistry;

    // @dev Mapping to store the credentials
    mapping(string => string[]) private didToCredentials;

    // @dev Error thrown when DID does not exist
    error DIDNotFound(string did);

    constructor() {
        didRegistry = new DIDRegistry();
        schemaRegistry = new SchemaRegistry();
        credDefRegistry = new CredentialDefinitionRegistry();
        revocationRegistry = new RevocationRegistry();
    }

    // @dev Function to register a DID
    // @param _did The DID
    // @param _context The context of the DID
    // @param _metadata The metadata of the DID
    // @notice This function is used to register a DID
    function registerDID(
        string memory _did,
        string memory _context,
        string memory _metadata
    ) public {
        didRegistry.registerDID(_did, _context, _metadata);
    }

    // @dev Function to update a DID
    // @param _did The DID
    // @param _context The context of the DID
    // @param _metadata The metadata of the DID
    // @notice This function is used to update a DID
    function updateDID(
        string memory _did,
        string memory _context,
        string memory _metadata
    ) public {
        didRegistry.updateDID(_did, _context, _metadata);
    }

    // @dev Function to get a DID
    // @param _did The DID
    // @return context The context of the DID
    // @return metadata The metadata of the DID
    // @notice This function is used to get a DID
    function getDID(
        string memory _did
    ) public view returns (string memory, string memory) {
        return didRegistry.getDID(_did);
    }

    // @dev Function to check if a DID exists
    // @param _did The DID to check
    // @return true if the DID exists, false otherwise
    function didExists(string memory _did) public view returns (bool) {
        try didRegistry.getDID(_did) returns (string memory, string memory) {
            return true;
        } catch {
            return false;
        }
    }

    // @dev Function to register a schema
    // @param _schemaId The schema id
    // @param _details The details of the schema
    // @param _issuerId The DID of the issuer
    // @notice This function is used to register a schema
    function registerSchema(
        string memory _schemaId,
        string memory _details,
        string memory _issuerId
    ) public {
        // Check if the issuer DID exists
        if (!didExists(_issuerId)) {
            revert DIDNotFound(_issuerId);
        }
        
        schemaRegistry.registerSchema(_schemaId, _details);
    }

    // @dev Function to add an approved issuer
    // @param _schemaId The schema id
    // @param _issuer The address of the issuer
    // @notice This function is used to add an approved issuer
    function addApprovedIssuer(
        string memory _schemaId,
        address _issuer
    ) public {
        schemaRegistry.addApprovedIssuer(_schemaId, _issuer);
    }

    // @dev Function to get a schema
    // @param _schemaId The schema id
    // @return schemaDetails The details of the schema
    // @return approvedIssuers The approved issuers of the schema
    // @notice This function is used to get a schema
    function getSchema(
        string memory _schemaId
    ) public view returns (string memory, address[] memory) {
        return schemaRegistry.getSchema(_schemaId);
    }

    // @dev Function to register a credential definition
    // @param _credDefId The credential definition id
    // @param _schemaId The schema id of the credential definition
    // @param _issuerId The DID of the issuer
    // @param _detailsJson The JSON string of the credential definition
    // @notice This function is used to register a credential definition
    function registerCredentialDefinition(
        string memory _credDefId,
        string memory _schemaId,
        string memory _issuerId,
        string memory _detailsJson
    ) public {
        // Check if the issuer DID exists
        if (!didExists(_issuerId)) {
            revert DIDNotFound(_issuerId);
        }
        
        credDefRegistry.registerCredentialDefinition(
            _credDefId,
            _schemaId,
            _issuerId,
            _detailsJson
        );
    }

    // @dev Function to get a credential definition
    // @param _credDefId The credential definition id
    // @return schemaId The schema id of the credential definition
    // @return issuerId The DID of the issuer
    // @return detailsJson The JSON string of the credential definition
    // @notice This function is used to get a credential definition
    function getCredentialDefinition(
        string memory _credDefId
    ) public view returns (string memory, string memory, string memory) {
        return credDefRegistry.getCredentialDefinition(_credDefId);
    }

    // @dev Function to revoke a credential
    // @param _credId The credential id
    // @notice This function is used to revoke a credential
    function revokeCredential(string memory _credId) public {
        revocationRegistry.revokeCredential(_credId);
    }

    // @dev Function to check if a credential is revoked
    // @param _credId The credential id
    // @notice This function is used to check if a credential is revoked
    function isCredentialRevoked(
        string memory _credId
    ) public view returns (bool) {
        return revocationRegistry.isCredentialRevoked(_credId);
    }
}
