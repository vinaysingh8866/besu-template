pragma solidity ^0.8.0;

contract RevocationRegistry {
    // @dev Struct to store the revocation entry
    struct RevocationEntry {
        uint createdDate;
        uint revokedDate;
        bool isRevoked;
    }

    // @dev Mapping to store the revocations
    mapping(string => RevocationEntry) public revocations;

    // @dev Function to create a credential
    // @param _credId The credential id
    // @notice This function is used to create a credential
    function createCredential(string memory _credId) public {
        uint createdDate = revocations[_credId].createdDate;
        require(createdDate == 0, "Credential already exists");
        uint currentTime = block.timestamp;
        revocations[_credId] = RevocationEntry(currentTime, 0, false);
    }

    // @dev Function to revoke a credential
    // @param _credId The credential id
    // @notice This function is used to revoke a credential
    function revokeCredential(string memory _credId) public {
        
        uint createdDate = revocations[_credId].createdDate;
        require(createdDate != 0, "Credential does not exist");
        require(
            !revocations[_credId].isRevoked,
            "Credential is already revoked"
        );
        revocations[_credId].isRevoked = true;
    }

    // @dev Function to check if a credential is revoked
    // @param _credId The credential id
    // @return isRevoked The status of the credential
    // @notice This function is used to check if a credential is revoked
    function isCredentialRevoked(
        string memory _credId
    ) public view returns (bool) {
        require(
            revocations[_credId].createdDate != 0,
            "Credential does not exist"
        );
        return revocations[_credId].isRevoked;
    }
}
