// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
 * @title Account Permissions Contract for Besu Network
 * @notice Controls which accounts can deploy smart contracts
 * @dev This contract is called by Besu nodes to check deployment permissions
 */
contract AccountPermissions {

    // Contract owner (can add/remove deployers)
    address public owner;

    // Mapping of addresses allowed to deploy contracts
    mapping(address => bool) public allowedDeployers;

    // List of allowed deployers for enumeration
    address[] public deployersList;

    // Events
    event DeployerAdded(address indexed deployer);
    event DeployerRemoved(address indexed deployer);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address[] memory initialDeployers) {
        owner = msg.sender;

        // Add initial deployers
        for (uint i = 0; i < initialDeployers.length; i++) {
            _addDeployer(initialDeployers[i]);
        }
    }

    /**
     * @notice Check if an account can deploy contracts
     * @param account Address to check
     * @return True if account is allowed to deploy
     */
    function canDeploy(address account) external view returns (bool) {
        return allowedDeployers[account];
    }

    /**
     * @notice Besu calls this function to check transaction permissions
     * @param sender Transaction sender
     * @param target Transaction target (0x0 for contract creation)
     * @param value Transaction value
     * @param gasPrice Gas price
     * @param gasLimit Gas limit
     * @param payload Transaction data
     * @return True if transaction is permitted
     */
    function transactionAllowed(
        address sender,
        address target,
        uint256 value,
        uint256 gasPrice,
        uint256 gasLimit,
        bytes calldata payload
    ) external view returns (bool) {
        // If target is 0x0, this is a contract deployment
        if (target == address(0)) {
            return allowedDeployers[sender];
        }

        // All other transactions are allowed
        return true;
    }

    /**
     * @notice Add an address to the deployers list
     * @param deployer Address to add
     */
    function addDeployer(address deployer) external onlyOwner {
        require(deployer != address(0), "Invalid address");
        _addDeployer(deployer);
    }

    /**
     * @notice Remove an address from the deployers list
     * @param deployer Address to remove
     */
    function removeDeployer(address deployer) external onlyOwner {
        require(allowedDeployers[deployer], "Address is not a deployer");

        allowedDeployers[deployer] = false;

        // Remove from list
        for (uint i = 0; i < deployersList.length; i++) {
            if (deployersList[i] == deployer) {
                deployersList[i] = deployersList[deployersList.length - 1];
                deployersList.pop();
                break;
            }
        }

        emit DeployerRemoved(deployer);
    }

    /**
     * @notice Get the list of all allowed deployers
     * @return Array of deployer addresses
     */
    function getAllDeployers() external view returns (address[] memory) {
        return deployersList;
    }

    /**
     * @notice Transfer ownership of the contract
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /**
     * Internal function to add a deployer
     */
    function _addDeployer(address deployer) internal {
        if (!allowedDeployers[deployer]) {
            allowedDeployers[deployer] = true;
            deployersList.push(deployer);
            emit DeployerAdded(deployer);
        }
    }
}
