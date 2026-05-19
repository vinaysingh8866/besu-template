# Besu Network - Deployment Troubleshooting Guide

This document details the issues encountered during initial deployment to Docker Desktop Kubernetes and their solutions.

## Deployment Date
October 25, 2025

## Environment
- **Platform:** macOS
- **Kubernetes:** Docker Desktop (v1.32.2)
- **Storage:** hostpath (Docker Desktop default)
- **Besu Version:** 25.10.0

---

## Issue #1: QBFT Genesis extraData RLP Encoding Error

### Symptoms
```
ERROR | Besu | Failed to start Besu: Input doesn't have enough data for RLP encoding
Expected current item to be a list, but it is: BYTE_ELEMENT
```

### Root Cause
The `extraData` field in the QBFT genesis.json file had incorrect RLP encoding. QBFT requires a very specific format for the genesis block's `extraData` field.

### Incorrect Format (Initial)
```json
"extraData": "0xf83ea00000000000000000000000000000000000000000000000000000000000000000d594c0"
```

This was too short and malformed.

### QBFT extraData Structure
The QBFT genesis `extraData` must contain:

```
RLP List [
  Voting Snapshot (32 bytes with 0xa0 prefix),
  Validator List (RLP list of addresses),
  Vote (empty, 0xc0),
  Round (0x80 for 0),
  Seals (empty list, 0xc0)
]
```

### Correct Format
```json
"extraData": "0xf87aa00000000000000000000000000000000000000000000000000000000000000000f854941fb0b967d992272f4e642f06fc729f81ae69474394d79fc9e961be2f9aa9e05e3d79eb042ac6451e5794bb9fa9f616573442f0d984b50738204dbf60b108943e989dd78caed60a0ad70386a617d5ae52eada23c080c0"
```

Breaking it down:
- `0xf87a` - Outer RLP list header (122 bytes payload)
- `a0` + 32 zero bytes - Voting snapshot (33 bytes total)
- `f854` - Validator list header (84 bytes payload)
  - `94` + 20 bytes - First validator address with RLP prefix
  - `94` + 20 bytes - Second validator address
  - `94` + 20 bytes - Third validator address
  - `94` + 20 bytes - Fourth validator address
- `c0` - Empty vote
- `80` - Round 0
- `c0` - Empty seals list

### Python Script to Generate Correct extraData

```python
#!/usr/bin/env python3

def generate_qbft_extradata(validator_addresses):
    """
    Generate proper QBFT genesis extraData

    Args:
        validator_addresses: List of validator addresses (without 0x prefix)

    Returns:
        Properly formatted extraData string with 0x prefix
    """
    # Voting snapshot: 32 bytes with a0 prefix
    vanity = "a0" + "00" * 32

    # Validators list: f854 for 4 validators (84 bytes)
    # Each address gets 94 prefix (RLP for 20-byte string)
    validators_rlp = "f854"
    for addr in validator_addresses:
        validators_rlp += "94" + addr

    # Vote (empty), round (0), seals (empty)
    vote = "c0"
    round_num = "80"
    seals = "c0"

    # Combine inner content
    inner = vanity + validators_rlp + vote + round_num + seals
    inner_bytes = len(inner) // 2

    # Outer RLP list header for 122 bytes: f87a
    header = "f87a"

    extra_data = "0x" + header + inner
    return extra_data

# Example usage with Besu Network validators
validators = [
    "1fb0b967d992272f4e642f06fc729f81ae694743",
    "d79fc9e961be2f9aa9e05e3d79eb042ac6451e57",
    "bb9fa9f616573442f0d984b50738204dbf60b108",
    "3e989dd78caed60a0ad70386a617d5ae52eada23",
]

extradata = generate_qbft_extradata(validators)
print(extradata)
```

### Solution Steps

1. Generated validator addresses from node keys
2. Created proper RLP-encoded extraData using the structure above
3. Updated `config/besu/genesis.json` with correct extraData
4. Updated Kubernetes ConfigMap
5. Restarted bootnode pod

### Verification
After fix, bootnode started successfully with:
```
INFO  | Runner | Ethereum main loop is up.
INFO  | DefaultP2PNetwork | Enode URL enode://...@0.0.0.0:30303
INFO  | BftMiningCoordinator | Starting BFT mining coordinator
```

---

## Issue #2: Storage Class Mismatch

### Symptoms
```
Warning  FailedScheduling  pod has unbound immediate PersistentVolumeClaims
PVC Status: Pending
```

PVC stuck in Pending state, pod cannot start.

### Root Cause
Kubernetes manifests specified `storageClassName: local-storage` which doesn't exist in Docker Desktop. Docker Desktop uses `hostpath` as the default storage class.

### Incorrect Configuration
```yaml
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-storage  # ❌ Doesn't exist
      resources:
        requests:
          storage: 20Gi
```

### Correct Configuration
```yaml
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: hostpath  # ✅ Docker Desktop default
      resources:
        requests:
          storage: 20Gi
```

### Solution
Created modified deployment script for Docker Desktop that automatically replaces `local-storage` with `hostpath`:

```bash
cat kubernetes/bootnode/statefulset.yaml | \
  sed 's/storageClassName: local-storage/storageClassName: hostpath/' | \
  kubectl apply -f -
```

### Storage Class by Platform

| Platform | Storage Class | Notes |
|----------|--------------|-------|
| Docker Desktop | `hostpath` | Default, uses host filesystem |
| Kind | `local-path` or `standard` | Depends on version |
| DigitalOcean | `do-block-storage` | SSD block storage |
| AWS EKS | `gp3` or `gp2` | EBS volumes |
| GCP GKE | `pd-ssd` or `pd-standard` | Persistent disks |
| Azure AKS | `managed-premium` | Azure disks |

---

## Issue #3: Persistent Database from Failed Attempts

### Symptoms
Even after fixing genesis file, bootnode continued to fail with:
```
ERROR | Besu | Failed to start Besu: Expected current item to be a list...
INFO  | RocksDBKeyValueStorageFactory | Existing database at /data.
```

### Root Cause
The init container checked if database exists before initializing:
```bash
if [ ! -f /data/database/METADATA.json ]; then
  # Initialize genesis
else
  echo "Genesis already initialized, skipping..."
fi
```

After failed attempts, the database existed but was incompatible with the new genesis file.

### Solution
Modified init container to **always clean and reinitialize** during development:

```yaml
initContainers:
  - name: init-genesis
    image: hyperledger/besu:latest
    command:
      - sh
      - -c
      - |
        echo "Cleaning old database..."
        rm -rf /data/database /data/caches
        echo "Initializing genesis block..."
        cp /config/genesis.json /data/genesis.json
        cp /secrets/key /data/key
        cp /secrets/key.pub /data/key.pub
```

**Note:** For production, restore the conditional check to preserve data across restarts.

---

## Issue #4: PVC Stuck in Terminating State

### Symptoms
```
NAME                   STATUS        VOLUME     CAPACITY   ACCESS MODES
data-besu-bootnode-0   Terminating   pvc-...    20Gi       RWO
```

PVC doesn't delete, pod cannot recreate with fresh storage.

### Root Cause
Kubernetes finalizers prevent immediate deletion. Sometimes PVCs get stuck when volumes are in use or have protection policies.

### Solution
Force remove finalizers to allow deletion:

```bash
kubectl patch pvc data-besu-bootnode-0 -n besu-network -p '{"metadata":{"finalizers":null}}'
```

Then delete pod to trigger recreation:
```bash
kubectl delete pod besu-bootnode-0 -n besu-network --force --grace-period=0
```

---

## Working Configuration Files

### Final Working Genesis File

Location: `config/besu/genesis.json`

```json
{
  "config": {
    "chainId": 1947,
    "berlinBlock": 0,
    "londonBlock": 0,
    "qbft": {
      "epochlength": 30000,
      "blockperiodseconds": 2,
      "requesttimeoutseconds": 10
    }
  },
  "nonce": "0x0",
  "timestamp": "0x58ee40ba",
  "gasLimit": "0x989680",
  "difficulty": "0x1",
  "mixHash": "0x63746963616c2062797a616e74696e65206661756c7420746f6c6572616e6365",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "alloc": {},
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "baseFeePerGas": "0x0",
  "extraData": "0xf87aa00000000000000000000000000000000000000000000000000000000000000000f854941fb0b967d992272f4e642f06fc729f81ae69474394d79fc9e961be2f9aa9e05e3d79eb042ac6451e5794bb9fa9f616573442f0d984b50738204dbf60b108943e989dd78caed60a0ad70386a617d5ae52eada23c080c0"
}
```

### Validator Addresses in Genesis

1. `0x1fb0b967d992272f4e642f06fc729f81ae694743`
2. `0xd79fc9e961be2f9aa9e05e3d79eb042ac6451e57`
3. `0xbb9fa9f616573442f0d984b50738204dbf60b108`
4. `0x3e989dd78caed60a0ad70386a617d5ae52eada23`

These correspond to the generated validator keys in `keys/validator-{0..3}/`

---

## Deployment Status

### ✅ Completed
1. **Kubernetes Context** - Switched to docker-desktop
2. **Node Keys Generated** - 6 nodes + 3 admin accounts
3. **Secrets Created** - All keys stored in Kubernetes secrets
4. **Genesis Fixed** - Proper QBFT extraData format
5. **Bootnode Deployed** - Running and listening for peers

### ⏳ Remaining
1. **Validators** - Deploy 4 validator StatefulSet
2. **RPC Node** - Deploy with permissioning config
3. **BlockScout** - Deploy explorer + PostgreSQL + Redis
4. **Monitoring** - Deploy Prometheus + Grafana

---

## Key Learnings

### 1. QBFT Genesis Complexity
QBFT's extraData format is very specific and poorly documented. The exact RLP encoding structure must be followed or the node will fail to start.

### 2. Platform-Specific Storage
Each Kubernetes platform has different default storage classes. Always check with `kubectl get storageclass` before deploying.

### 3. Database Persistence
Besu's init logic assumes database persistence. During development/debugging, force clean databases when genesis changes.

### 4. Resource Cleanup
When debugging Kubernetes, sometimes resources (PVCs, pods) get stuck. Know how to force-delete using finalizer patches.

---

## Recommended Deployment Script for Docker Desktop

Created: `scripts/deploy-docker-desktop.sh`

This script:
1. Checks kubectl context is docker-desktop
2. Generates keys if missing
3. Creates/verifies secrets
4. Modifies manifests to use `hostpath` storage
5. Deploys all components in correct order
6. Waits for each component to be ready
7. Tests RPC endpoint

Usage:
```bash
./scripts/deploy-docker-desktop.sh
```

---

## Next Steps for Validators

When deploying validators, they will need:
1. The same fixed genesis.json in their ConfigMap
2. hostpath storage class
3. static-nodes.json with bootnode enode URL
4. Individual node keys from secrets

The validators will automatically:
- Connect to bootnode
- Discover each other
- Start QBFT consensus when 3+ validators are online
- Begin producing blocks

---

## References

- [Hyperledger Besu QBFT Documentation](https://besu.hyperledger.org/private-networks/concepts/qbft)
- [RLP Encoding Specification](https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/)
- [Besu Genesis Configuration](https://besu.hyperledger.org/private-networks/reference/genesis-items)
- [Kubernetes Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)

---

## Troubleshooting Commands

### Check Pod Status
```bash
kubectl get pods -n besu-network
kubectl describe pod besu-bootnode-0 -n besu-network
```

### View Logs
```bash
kubectl logs besu-bootnode-0 -n besu-network
kubectl logs besu-bootnode-0 -n besu-network -c init-genesis
```

### Check Storage
```bash
kubectl get pvc -n besu-network
kubectl get storageclass
```

### Force Delete Resources
```bash
# Delete pod
kubectl delete pod <pod-name> -n besu-network --force --grace-period=0

# Remove PVC finalizers
kubectl patch pvc <pvc-name> -n besu-network -p '{"metadata":{"finalizers":null}}'
```

### Update ConfigMap
```bash
kubectl delete configmap besu-bootnode-config -n besu-network
kubectl create configmap besu-bootnode-config \
  --from-file=config/besu/genesis.json \
  -n besu-network
```

---

## Contact & Support

For issues with Besu Network deployment, refer to:
- This troubleshooting guide
- [Besu Discord](https://discord.gg/hyperledger)
- [Hyperledger Besu GitHub Issues](https://github.com/hyperledger/besu/issues)
