pragma solidity ^0.8.0;

contract DIDRegistry {
    // @dev Struct to store the DID details
    // @param context The context of the DID
    // @param metadata The metadata of the DID
    struct DID {
        string context;
        string metadata;
    }

    // @dev Mapping to store the DIDs
    mapping(string => DID) public dids;

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
        require(bytes(dids[_did].context).length == 0, "DID already exists");
        dids[_did] = DID(_context, _metadata);
    }

    // @dev Function to get a DID
    // @param _did The DID
    // @return context The context of the DID
    // @return metadata The metadata of the DID
    // @notice This function is used to get a DID
    function getDID(
        string memory _did
    ) public view returns (string memory, string memory) {
        require(bytes(dids[_did].context).length != 0, "DID does not exist");
        return (dids[_did].context, dids[_did].metadata);
    }

    function updateDID(
        string memory _did,
        string memory _context,
        string memory _metadata
    ) public {
        require(bytes(dids[_did].context).length != 0, "DID does not exist");
        dids[_did] = DID(_context, _metadata);
    }
}
