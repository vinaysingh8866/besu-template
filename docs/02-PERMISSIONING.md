# Besu Network - Permissioning Guide

How contract deployment permissioning works on Besu Network and how to manage the whitelist.

## Overview

Besu Network uses **account permissioning** to control who can deploy smart contracts:

- ✅ **Anyone can send transactions** (transfers, contract calls)
- ✅ **Anyone can interact with deployed contracts**
- ❌ **Only whitelisted accounts can deploy new contracts**
- ✅ **Zero gas for all operations**

This prevents unauthorized contract deployment while keeping the network public for use.

## How It Works

### Technical Implementation

1. **Configuration File:** `config/besu/permissioning-config.toml`
   - Contains list of whitelisted Ethereum addresses
   - Loaded by RPC node on startup

2. **Besu Configuration:**
   - RPC node runs with `--permissions-accounts-config-file-enabled`
   - Checks every transaction before execution
   - Blocks contract deployment from non-whitelisted addresses

3. **Transaction Types:**
   - Regular transfer: `to` address specified → ✅ Allowed for everyone
   - Contract call: `to` address is contract → ✅ Allowed for everyone
   - Contract deployment: `to` address is null → ⚠️ Only whitelisted

## Managing the Whitelist

### View Current Whitelist

```bash
# Using script
cat config/besu/permissioning-config.toml | grep "0x"

# From Kubernetes
kubectl get configmap besu-rpc-config -n besu-network \
  -o jsonpath='{.data.permissioning-config\.toml}' | grep "0x"

# Using status script
./scripts/status.sh
```

### Add Account to Whitelist

#### Method 1: Using Script (Recommended)

```bash
./scripts/add-deployer.sh 0xYourEthereumAddress
```

This automatically:
1. Adds address to `permissioning-config.toml`
2. Updates Kubernetes ConfigMap
3. Restarts RPC node
4. Waits for node to be ready

#### Method 2: Manual Addition

1. Edit `config/besu/permissioning-config.toml`:
   ```toml
   accounts-allowlist = [
     "0x1234...",  # Existing address
     "0x5678...",  # Your new address
   ]
   ```

2. Update ConfigMap:
   ```bash
   kubectl create configmap besu-rpc-config \
     --from-file=genesis.json=config/besu/genesis.json \
     --from-file=permissioning-config.toml=config/besu/permissioning-config.toml \
     --namespace=besu-network \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

3. Restart RPC node:
   ```bash
   kubectl rollout restart deployment/besu-rpc -n besu-network
   kubectl rollout status deployment/besu-rpc -n besu-network
   ```

### Remove Account from Whitelist

1. Edit `config/besu/permissioning-config.toml`
   - Remove the address line

2. Update ConfigMap:
   ```bash
   kubectl create configmap besu-rpc-config \
     --from-file=genesis.json=config/besu/genesis.json \
     --from-file=permissioning-config.toml=config/besu/permissioning-config.toml \
     --namespace=besu-network \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

3. Restart RPC node:
   ```bash
   kubectl rollout restart deployment/besu-rpc -n besu-network
   ```

## Admin Accounts

### Generated Admin Accounts

Three admin accounts are automatically generated during setup:

```bash
cat keys/admin/ADMIN_ACCOUNTS.txt
```

Example output:
```
Admin Account 1:
  Address:     0xabcd...
  Private Key: 0x1234...

Admin Account 2:
  Address:     0xefgh...
  Private Key: 0x5678...

Admin Account 3:
  Address:     0xijkl...
  Private Key: 0x9abc...
```

### Securing Admin Keys

**Best Practices:**

1. **Never commit keys to Git**
   - Keys are in `.gitignore`
   - Verify: `git status` should not show `keys/` directory

2. **Store keys securely**
   - Use password manager (1Password, LastPass, etc.)
   - Or hardware wallet for production
   - Encrypted backup

3. **Limit key distribution**
   - Only share with authorized personnel
   - Use separate accounts for different purposes

4. **Rotate keys periodically**
   - Generate new admin account
   - Add to whitelist
   - Remove old account after transition

### Generating Additional Admin Accounts

Using ethers.js:

```javascript
const { ethers } = require('ethers');

// Generate new wallet
const wallet = ethers.Wallet.createRandom();

console.log('Address:', wallet.address);
console.log('Private Key:', wallet.privateKey);
```

Using Python (web3.py):

```python
from eth_account import Account

# Generate new account
account = Account.create()

print(f'Address: {account.address}')
print(f'Private Key: {account.key.hex()}')
```

Then add the address to whitelist:
```bash
./scripts/add-deployer.sh <NEW_ADDRESS>
```

## Testing Permissioning

### Test 1: Whitelisted Account Can Deploy

```javascript
// Using ethers.js with admin account
const { ethers } = require('ethers');

const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
const wallet = new ethers.Wallet('ADMIN_PRIVATE_KEY', provider);

// Simple contract
const abi = [...];
const bytecode = '0x...';

const factory = new ethers.ContractFactory(abi, bytecode, wallet);
const contract = await factory.deploy();
await contract.deployed();

console.log('Contract deployed at:', contract.address);
// ✅ Should succeed
```

### Test 2: Non-Whitelisted Account Cannot Deploy

```javascript
// Using ethers.js with random account
const randomWallet = ethers.Wallet.createRandom().connect(provider);

const factory = new ethers.ContractFactory(abi, bytecode, randomWallet);

try {
  const contract = await factory.deploy();
  await contract.deployed();
  console.log('Deployed'); // Should not reach here
} catch (error) {
  console.log('Deployment blocked:', error.message);
  // ✅ Should fail with permission error
}
```

### Test 3: Anyone Can Send Transactions

```javascript
// Random account can send Besu tokens
const randomWallet = ethers.Wallet.createRandom().connect(provider);

const tx = await randomWallet.sendTransaction({
  to: '0xRecipientAddress',
  value: ethers.utils.parseEther('1.0')
});

await tx.wait();
console.log('Transaction sent:', tx.hash);
// ✅ Should succeed
```

### Test 4: Anyone Can Call Contracts

```javascript
// Random account can call deployed contract
const contract = new ethers.Contract(contractAddress, abi, randomWallet);

const result = await contract.someFunction();
console.log('Function result:', result);
// ✅ Should succeed
```

## Smart Contract Permissioning (Advanced)

For more complex permissioning, you can deploy smart contracts that manage permissions:

### Example: On-Chain Permissioning Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DeployerRegistry {
    mapping(address => bool) public allowedDeployers;
    address public admin;

    event DeployerAdded(address indexed deployer);
    event DeployerRemoved(address indexed deployer);

    constructor() {
        admin = msg.sender;
        allowedDeployers[msg.sender] = true;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    function addDeployer(address deployer) external onlyAdmin {
        allowedDeployers[deployer] = true;
        emit DeployerAdded(deployer);
    }

    function removeDeployer(address deployer) external onlyAdmin {
        allowedDeployers[deployer] = false;
        emit DeployerRemoved(deployer);
    }

    function isAllowed(address deployer) external view returns (bool) {
        return allowedDeployers[deployer];
    }
}
```

## Troubleshooting

### Issue: Contract deployment fails with permission error

**Solution:**
1. Verify address is whitelisted:
   ```bash
   cat config/besu/permissioning-config.toml | grep "0xYourAddress"
   ```

2. If not, add it:
   ```bash
   ./scripts/add-deployer.sh 0xYourAddress
   ```

3. Wait for RPC node to restart

### Issue: Added address but still can't deploy

**Solution:**
1. Check RPC node restarted:
   ```bash
   kubectl get pods -l app=besu-rpc -n besu-network
   ```

2. Check RPC logs for permissioning:
   ```bash
   kubectl logs -l app=besu-rpc -n besu-network | grep -i permission
   ```

3. Verify ConfigMap updated:
   ```bash
   kubectl get configmap besu-rpc-config -n besu-network -o yaml | grep "0xYourAddress"
   ```

### Issue: Want to disable permissioning temporarily

**Solution:**
Edit RPC deployment to remove permissioning flags:

```bash
kubectl edit deployment besu-rpc -n besu-network

# Remove these lines from container args:
# - --permissions-accounts-config-file-enabled=true
# - --permissions-accounts-config-file=/data/permissioning-config.toml
```

**Warning:** This allows anyone to deploy contracts!

## Production Considerations

### For Production Deployment:

1. **Use Hardware Wallets** for admin keys
   - Ledger, Trezor, etc.
   - Never store private keys in plain text

2. **Implement Multi-Sig**
   - Require multiple approvals for adding deployers
   - Use Gnosis Safe or similar

3. **Audit Trail**
   - Log all whitelist changes
   - Keep record of who requested additions

4. **Regular Review**
   - Audit whitelist quarterly
   - Remove unused addresses

5. **Backup Strategy**
   - Secure backup of admin keys
   - Document recovery process

6. **Monitoring**
   - Alert on failed deployment attempts
   - Track contract deployment activity

## Resources

- [Besu Permissioning Documentation](https://besu.hyperledger.org/en/stable/Concepts/Permissioning/Permissioning-Overview/)
- [Account Permissioning](https://besu.hyperledger.org/en/stable/HowTo/Limit-Access/Local-Permissioning/)
- [Smart Contract Permissioning](https://besu.hyperledger.org/en/stable/Tutorials/Permissioning/Getting-Started-Onchain-Permissioning/)
