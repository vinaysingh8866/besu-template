# Besu Network - Local Development Setup

Complete guide for setting up the Besu Network on your local machine. The supported local target is **Docker Desktop's built-in Kubernetes**; Kind is also documented but no longer the primary path.

**Besu version:** all pods are pinned to `hyperledger/besu:26.5.0`.
**EVM:** Shanghai/Cancun/Prague activated at genesis (PUSH0, MCOPY, TLOAD/TSTORE available).
**Consensus:** QBFT, 4 validators, 2-second block time.
**Chain ID:** 1947, gas price 0.

## Prerequisites

### System Requirements

- **Operating System:** macOS (Intel or Apple Silicon)
- **RAM:** 16GB+ recommended (minimum 8GB)
- **CPU:** 4+ cores recommended
- **Disk Space:** 50GB+ free space
- **Docker Desktop:** 4GB+ memory allocation

### Required Tools

1. **Docker Desktop**
   ```bash
   # Download from: https://docs.docker.com/desktop/install/mac-install/
   # Or install via Homebrew:
   brew install --cask docker
   ```

2. **kubectl** (Kubernetes CLI)
   ```bash
   brew install kubectl
   ```

3. **jq** (JSON processor)
   ```bash
   brew install jq
   ```

4. **openssl** (usually pre-installed on macOS)
   ```bash
   brew install openssl
   ```

5. **yarn** (for Kanon contract deploy)
   ```bash
   brew install yarn
   ```

6. **(Optional)** Kind — only if you prefer Kind over Docker Desktop's built-in Kubernetes
   ```bash
   brew install kind
   ```

Enable Kubernetes in Docker Desktop (Settings → Kubernetes → Enable) and make sure the context is `docker-desktop`:

```bash
kubectl config use-context docker-desktop
kubectl get nodes   # should show one Ready node named docker-desktop
```

### Verify Installation

Run the prerequisites checker:

```bash
./scripts/00-prerequisites.sh
```

This will verify all tools are installed correctly.

## Deployment Steps

### Option 1: One-shot Docker Desktop deploy (recommended)

```bash
kubectl config use-context docker-desktop
chmod +x scripts/*.sh
./scripts/deploy-docker-desktop.sh
```

This script:
1. Switches to docker-desktop context (prompts if not already there)
2. Generates node keys on first run (skipped if `keys/` already exists)
3. Creates k8s secrets from the keys
4. Builds the shared **`besu-config`** and **`besu-rpc-config`** ConfigMaps imperatively from `config/besu/*.json` and `config/besu/permissioning-config.toml` — this is the single source of truth for genesis, static-nodes, and permissioning
5. Applies bootnode, validators, RPC, BlockScout (+ Postgres/Redis), Prometheus, Grafana
6. Port-forwards `localhost:8545 → besu-rpc-internal:8545` and verifies `eth_chainId` returns `0x79b` (1947)
7. Compiles `kanon_contracts/contracts/kanon/Kanon.sol` (and its sub-registries) and deploys them via Hardhat; addresses are persisted to `kanon_contracts/deployments/1947.json`

The port-forward runs only while the script is in the foreground. To keep `localhost:8545` reachable after it exits:

```bash
kubectl port-forward -n besu-network svc/besu-rpc-internal 8545:8545
```

Estimated time: 5–10 minutes after the first run (slower on first run because images pull and Hardhat installs dependencies).

### Option 2: Manual Step-by-Step Deployment

For more control, run each step manually:

#### Step 1: Cluster

On Docker Desktop: just enable Kubernetes in Settings → Kubernetes. No script needed.

(Optional, alternative) Create a Kind cluster:
```bash
./scripts/01-setup-kind-cluster.sh
```
This creates 1 control plane + 3 workers with port mappings and a local storage provisioner.

Verify cluster:
```bash
kubectl cluster-info
kubectl get nodes
```

#### Step 2: Generate Node Keys

```bash
./scripts/02-generate-node-keys.sh
```

This generates:
- Private keys for all 6 nodes (bootnode + 4 validators + RPC)
- 3 admin accounts with private keys
- Updates genesis.json with validator addresses
- Creates static-nodes.json for peer discovery
- Updates permissioning-config.toml with admin addresses

**Important:** Keys are saved in `keys/` directory. Keep them secure!

Admin accounts summary: `keys/admin/ADMIN_ACCOUNTS.txt`

#### Step 3: Create Kubernetes Secrets

```bash
./scripts/03-create-secrets.sh
```

This creates secrets for:
- Node private keys
- PostgreSQL password
- BlockScout secret key
- Grafana admin password

Verify secrets:
```bash
kubectl get secrets -n besu-network
```

#### Step 4: Deploy Network

For docker-desktop, use:
```bash
./scripts/deploy-docker-desktop.sh
```

For Kind (or any cluster with a `local-storage` storage class), use:
```bash
./scripts/04-deploy-network.sh
```

Both scripts:
1. Create the shared **`besu-config`** ConfigMap from `config/besu/{genesis.json,static-nodes.json}` (single source of truth — no embedded genesis in any manifest)
2. Create **`besu-rpc-config`** from `config/besu/permissioning-config.toml`
3. Apply manifests in order: bootnode → validators (parallel pod management) → RPC → BlockScout stack → monitoring
4. Port-forward `localhost:8545` and deploy Kanon contracts (docker-desktop only)

Watch progress:
```bash
kubectl get pods -n besu-network -w
```

This takes 5-10 minutes.

## Accessing the Network

### RPC Endpoint

**HTTP:**
```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

**WebSocket:**
```bash
wscat -c ws://localhost:8546
```

### BlockScout Explorer

Open in browser: http://localhost:4000

Features:
- Search transactions, blocks, addresses
- View contract code
- Verify smart contracts
- API access

### Grafana Dashboard

1. Open: http://localhost:3000
2. Login: `admin` / `admin`
3. Change password on first login
4. Dashboards > Browse > Select Besu metrics

### Prometheus

Open: http://localhost:9090

Query examples:
- `besu_blockchain_height` - Current block height
- `besu_peers_connected_total` - Peer count
- `besu_transaction_pool_transactions` - Pending transactions

## Keys and accounts: what persists, what's fixed

Two categories with different lifecycles:

### Generated keys (persist across redeploys)

`scripts/02-generate-node-keys.sh` writes everything into `keys/`:
- `keys/bootnode/`, `keys/validator-{0..3}/`, `keys/rpc/` — node identity keys
- `keys/admin/admin-{1,2,3}.{key,address}` — three optional admin accounts (declarative; not currently enforced as deployers)
- `keys/admin/ADMIN_ACCOUNTS.txt` — human-readable summary

The deploy scripts skip regeneration when `keys/` already exists, so reruns are idempotent.

**The entire `keys/` directory is gitignored** (`.gitignore` line `keys/`), and every `*.key`, `*.pub`, and `*ADMIN_ACCOUNTS.txt` is also gitignored as a belt-and-suspenders match. Never commit anything under `keys/`.

To rotate node keys (destroys the chain — genesis `extraData` and `static-nodes.json` are tied to the keys):

```bash
rm -rf keys/
./scripts/02-generate-node-keys.sh
./scripts/03-create-secrets.sh
kubectl delete pvc -n besu-network --all     # wipe stale chain state and stale key files baked into PVCs
./scripts/deploy-docker-desktop.sh
```

### Kanon deployer (auto-generated, never committed)

There is no hardcoded deployer. The Kanon contracts are deployed using **admin account #1**:
- `scripts/02-generate-node-keys.sh` generates `keys/admin/admin-1.key` (32-byte random hex via `openssl rand -hex 32`)
- The same script writes its address into `config/besu/genesis.json` `alloc` (pre-funded) and `config/besu/permissioning-config.toml` `accounts-allowlist`
- `kanon_contracts/hardhat.config.ts` auto-loads the key from `keys/admin/admin-1.key` at runtime

So rotating `keys/` rotates the deployer transparently. Override for non-local networks:

```bash
export BESU_DEPLOYER_KEY=0x<your private key>
yarn deploy:besu-local
```

Resolution order in `hardhat.config.ts`:
1. `BESU_DEPLOYER_KEY` env var (highest priority — set this in CI/prod)
2. `keys/admin/admin-1.key` on disk (the default for local dev)
3. Empty — the network has no signer and `deploy` will fail with a clear error

## Deploying the Kanon contracts

`scripts/deploy-docker-desktop.sh` does this automatically as its last step, but you can re-run it any time:

```bash
# Make sure RPC is reachable on localhost:8545 (start a port-forward if not)
kubectl port-forward -n besu-network svc/besu-rpc-internal 8545:8545 &

cd kanon_contracts
yarn install        # first run only
yarn deploy:besu-local
```

The deploy script writes a record to `kanon_contracts/deployments/1947.json` with all five contract addresses (Kanon + DIDRegistry + SchemaRegistry + CredentialDefinitionRegistry + RevocationRegistry). Re-running deploys fresh instances at new addresses; the old ones remain on-chain.

## Using Admin Accounts

### Import to Metamask

1. Open Metamask
2. Click account icon > Import Account
3. Paste private key from `keys/admin/ADMIN_ACCOUNTS.txt`
4. Add network:
   - Network Name: Besu Network
   - RPC URL: http://localhost:8545
   - Chain ID: 1947
   - Currency Symbol: Besu

### Deploy a Contract

Example using Remix:

1. Open https://remix.ethereum.org
2. Create your smart contract
3. Compile
4. Deploy & Run Transactions tab
5. Environment: Injected Provider (Metamask)
6. Select Besu Network in Metamask
7. Deploy (gas price will be 0)

### Using ethers.js

```javascript
const { ethers } = require('ethers');

const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
const wallet = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);

// Deploy contract
const factory = new ethers.ContractFactory(abi, bytecode, wallet);
const contract = await factory.deploy();
await contract.deployed();
```

## Management

### Check Network Status

```bash
./scripts/status.sh
```

Shows:
- Pod status
- Services
- Storage
- Blockchain info (chain ID, block height, peers)
- Whitelisted deployers

### View Logs

```bash
./scripts/logs.sh
```

Interactive menu to view logs from:
- Bootnode
- Validators
- RPC node
- BlockScout
- Databases
- Monitoring

### Add Contract Deployer

```bash
./scripts/add-deployer.sh 0xYourEthereumAddress
```

This will:
1. Add address to permissioning config
2. Update Kubernetes ConfigMap
3. Restart RPC node to apply changes

### Reset Network

Delete all blockchain data and start fresh:

```bash
./scripts/reset-network.sh
```

**Warning:** This deletes all transactions and blocks!

### Complete Cleanup

Remove everything (cluster, data, but keeps keys):

```bash
./scripts/cleanup.sh
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl get pods -n besu-network

# Describe pod for events
kubectl describe pod <pod-name> -n besu-network

# Check logs
kubectl logs <pod-name> -n besu-network
```

### RPC not responding

```bash
# Check if RPC pod is running
kubectl get pods -l app=besu-rpc -n besu-network

# Check RPC logs
kubectl logs -f -l app=besu-rpc -n besu-network

# Port forward — required for localhost:8545 to work on docker-desktop
kubectl port-forward svc/besu-rpc-internal 8545:8545 -n besu-network

# Alternatively, the NodePort service exposes RPC at :30545 directly
curl -X POST http://localhost:30545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

### Validators not peering / no blocks produced

QBFT pods need DNS, the right p2p host advertisement, and the headless service to expose not-Ready pods. If you see `Moved to round N` in validator logs but no `Produced empty block` lines, check:

```bash
# 1. Pod DNS resolves (must work even when pods are NotReady)
kubectl exec -n besu-network besu-bootnode-0 -- sh -c \
  'getent hosts besu-validator-0.besu-validator'
# Expect: <pod-ip>  besu-validator-0.besu-validator.besu-network.svc.cluster.local

# 2. Headless services have publishNotReadyAddresses: true
kubectl get svc besu-bootnode besu-validator -n besu-network -o yaml \
  | grep publishNotReady

# 3. Validator advertises pod IP (not 0.0.0.0)
kubectl logs -n besu-network besu-validator-0 | grep "Enode URL"
# Expect: enode://...@<pod-ip>:30303  (not @0.0.0.0:30303)

# 4. Peer count from any node
kubectl exec -n besu-network besu-rpc-... -- curl -s -X POST localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
```

### BlockScout not loading

```bash
# Check BlockScout logs
kubectl logs -f -l app=blockscout -n besu-network

# Check PostgreSQL
kubectl logs -f -l app=blockscout-postgres -n besu-network

# Check if RPC is accessible from BlockScout
kubectl exec -it deploy/blockscout -n besu-network -- curl http://besu-rpc-internal:8545
```

### Validators not reaching consensus

```bash
# Check validator logs
kubectl logs -f besu-validator-0 -n besu-network

# Check peer connections
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
```

### Insufficient resources

If pods are pending due to insufficient CPU/memory:

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n besu-network

# Scale down validators
kubectl scale statefulset besu-validator --replicas=3 -n besu-network
```

## Network Configuration

### Genesis Configuration

Location: `config/besu/genesis.json`

Key settings:
- `chainId`: 1947
- `qbft.blockperiodseconds`: 2 (block time)
- `baseFeePerGas`: 0 (free gas)

### Permissioning Configuration

Location: `config/besu/permissioning-config.toml`

Modify to add/remove deployer addresses.

Apply changes to the **`besu-rpc-config`** ConfigMap (RPC-only — permissioning lives here):

```bash
kubectl create configmap besu-rpc-config \
  --from-file=permissioning-config.toml=config/besu/permissioning-config.toml \
  -n besu-network --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment/besu-rpc -n besu-network
```

Apply changes to the **shared `besu-config`** ConfigMap (genesis + static-nodes — used by bootnode, validators, RPC):

```bash
kubectl create configmap besu-config \
  --from-file=genesis.json=config/besu/genesis.json \
  --from-file=static-nodes.json=config/besu/static-nodes.json \
  -n besu-network --dry-run=client -o yaml | kubectl apply -f -

# Genesis changes only take effect when the chain DB is wiped:
kubectl delete pvc -n besu-network -l app=besu-bootnode -l app=besu-validator
kubectl delete pvc besu-rpc-data -n besu-network
kubectl rollout restart statefulset/besu-bootnode statefulset/besu-validator -n besu-network
kubectl rollout restart deployment/besu-rpc -n besu-network
```

⚠ Changing genesis after a chain has produced blocks invalidates that chain — pods will fail to start because the on-disk DB doesn't match the new genesis hash. Wipe PVCs first.

## Next Steps

- [Architecture Guide](01-ARCHITECTURE.md) - Understand the system design
- [Permissioning Guide](02-PERMISSIONING.md) - Manage access control
- [Operations Guide](03-OPERATIONS.md) - Day-to-day operations
- [Production Deployment](05-PRODUCTION-DEPLOY.md) - Deploy to cloud

## Resources

- [Hyperledger Besu Documentation](https://besu.hyperledger.org/)
- [QBFT Consensus](https://besu.hyperledger.org/private-networks/concepts/qbft)
- [BlockScout Documentation](https://docs.blockscout.com/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
