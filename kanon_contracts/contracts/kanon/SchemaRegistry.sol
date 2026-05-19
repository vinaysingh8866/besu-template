pragma solidity ^0.8.0;

contract SchemaRegistry {
    // @dev Struct to store the schema details
    struct Schema {
        string schemaDetails;
        address[] approvedIssuers;
    }

    // @dev Function modifier to check if the issuer is approved
    modifier onlyApprovedIssuer(string memory _schemaId) {
        bool isApproved = false;
        for (uint i = 0; i < schemas[_schemaId].approvedIssuers.length; i++) {
            if (schemas[_schemaId].approvedIssuers[i] == msg.sender) {
                isApproved = true;
                break;
            }
        }
        require(isApproved, "Only approved issuer can perform this action");
        _;
    }

    address public owner;
    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    // @dev Mapping to store the schemas
    mapping(string => Schema) schemas;

    // @dev Function to register a schema
    // @param _schemaId The schema id
    // @param _details The details of the schema
    // @notice This function is used to register a schema
    function registerSchema(
        string memory _schemaId,
        string memory _details
    ) public {
        require(
            bytes(schemas[_schemaId].schemaDetails).length == 0,
            "Schema already exists"
        );
        schemas[_schemaId] = Schema(_details, new address[](0));
    }

    // @dev Function to add an approved issuer
    // @param _schemaId The schema id
    // @param _issuer The address of the issuer
    // @notice This function is used to add an approved issuer
    function addApprovedIssuer(
        string memory _schemaId,
        address _issuer
    ) public onlyOwner {
        require(
            bytes(schemas[_schemaId].schemaDetails).length != 0,
            "Schema does not exist"
        );
        schemas[_schemaId].approvedIssuers.push(_issuer);
    }

    // @dev Function to get a schema
    // @param _schemaId The schema id
    // @return schemaDetails The details of the schema
    // @return approvedIssuers The approved issuers of the schema
    // @notice This function is used to get a schema
    function getSchema(
        string memory _schemaId
    ) public view returns (string memory, address[] memory) {
        require(
            bytes(schemas[_schemaId].schemaDetails).length != 0,
            "Schema does not exist"
        );
        return (
            schemas[_schemaId].schemaDetails,
            schemas[_schemaId].approvedIssuers
        );
    }
}
