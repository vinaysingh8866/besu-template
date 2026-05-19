#!/bin/bash

# Besu Network - Docker Desktop Deployment
# Deploys Besu Network to Docker Desktop Kubernetes

set -e

NAMESPACE="besu-network"
STORAGE_CLASS="hostpath"

echo "=================================================="
echo "  Besu Network - Docker Desktop Deployment"
echo "  Chain ID: 1947"
echo "=================================================="
echo ""

# Check we're on Docker Desktop context
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "docker-desktop" ]; then
    echo "⚠️  Warning: Not using docker-desktop context!"
    echo "   Current context: $CURRENT_CONTEXT"
    read -p "Switch to docker-desktop? (Y/n): " -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        kubectl config use-context docker-desktop
    fi
fi

# Check if keys exist
if [ ! -d "keys" ]; then
    echo "⚠️  Keys not found. Generating node keys..."
    ./scripts/02-generate-node-keys.sh
fi

echo "Step 1: Creating namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
echo "✓ Namespace created/verified"

echo ""
echo "Step 2: Creating secrets..."

# Check if secrets already exist
if kubectl get secret besu-bootnode-keys -n ${NAMESPACE} >/dev/null 2>&1; then
    echo "  Secrets already exist, skipping..."
else
    ./scripts/03-create-secrets.sh
fi

echo ""
echo "Step 2b: Creating shared config ConfigMaps from canonical files..."
kubectl create configmap besu-config \
    --from-file=genesis.json=config/besu/genesis.json \
    --from-file=static-nodes.json=config/besu/static-nodes.json \
    -n ${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap besu-rpc-config \
    --from-file=permissioning-config.toml=config/besu/permissioning-config.toml \
    -n ${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -
echo "✓ besu-config and besu-rpc-config ConfigMaps created/updated"

echo ""
echo "Step 3: Updating manifests for Docker Desktop storage..."

# Create temporary directory for modified manifests
TEMP_DIR=$(mktemp -d)
echo "  Using temp directory: $TEMP_DIR"

# Copy all manifests and replace storage class
for dir in bootnode validators rpc blockscout monitoring/prometheus monitoring/grafana; do
    mkdir -p ${TEMP_DIR}/${dir}
    cp kubernetes/${dir}/*.yaml ${TEMP_DIR}/${dir}/ 2>/dev/null || true

    # Replace local-storage with hostpath
    find ${TEMP_DIR}/${dir} -name "*.yaml" -type f -exec sed -i.bak "s/storageClassName: local-storage/storageClassName: ${STORAGE_CLASS}/g" {} \;

    # Remove backup files
    find ${TEMP_DIR}/${dir} -name "*.bak" -delete
done

echo "✓ Manifests prepared"

echo ""
echo "Step 4: Deploying bootnode..."
kubectl apply -f ${TEMP_DIR}/bootnode/
echo "✓ Bootnode deployed"

echo "  Waiting for bootnode to be ready..."
kubectl wait --for=condition=ready pod -l app=besu-bootnode -n ${NAMESPACE} --timeout=300s || true

echo ""
echo "Step 5: Deploying validators..."
kubectl apply -f ${TEMP_DIR}/validators/
echo "✓ Validators deployed"

echo "  Waiting for validators to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l app=besu-validator -n ${NAMESPACE} --timeout=600s || true

echo ""
echo "Step 6: Deploying RPC node..."
kubectl apply -f ${TEMP_DIR}/rpc/
echo "✓ RPC node deployed"

echo "  Waiting for RPC node to be ready..."
kubectl wait --for=condition=ready pod -l app=besu-rpc -n ${NAMESPACE} --timeout=300s || true

echo ""
echo "Step 7: Deploying PostgreSQL for BlockScout..."
kubectl apply -f ${TEMP_DIR}/blockscout/postgres-statefulset.yaml
echo "✓ PostgreSQL deployed"

echo "  Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=blockscout-postgres -n ${NAMESPACE} --timeout=300s || true

echo ""
echo "Step 8: Deploying Redis for BlockScout..."
kubectl apply -f ${TEMP_DIR}/blockscout/redis-deployment.yaml
echo "✓ Redis deployed"

echo "  Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=blockscout-redis -n ${NAMESPACE} --timeout=180s || true

echo ""
echo "Step 9: Deploying BlockScout..."
kubectl apply -f ${TEMP_DIR}/blockscout/blockscout-deployment.yaml
echo "✓ BlockScout deployed"

echo "  Waiting for BlockScout to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l app=blockscout -n ${NAMESPACE} --timeout=600s || true

echo ""
echo "Step 10: Deploying Prometheus..."
kubectl apply -f ${TEMP_DIR}/monitoring/prometheus/deployment.yaml
echo "✓ Prometheus deployed"

echo "  Waiting for Prometheus to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus -n ${NAMESPACE} --timeout=300s || true

echo ""
echo "Step 11: Deploying Grafana..."
kubectl apply -f ${TEMP_DIR}/monitoring/grafana/deployment.yaml
echo "✓ Grafana deployed"

echo "  Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app=grafana -n ${NAMESPACE} --timeout=300s || true

# Cleanup temp directory
echo ""
echo "Cleaning up temporary files..."
rm -rf ${TEMP_DIR}

echo ""
echo "=================================================="
echo "✓ Besu Network deployed to Docker Desktop!"
echo ""
echo "Network Status:"
kubectl get pods -n ${NAMESPACE}
echo ""
echo "Access Points:"
echo "  RPC Endpoint (HTTP): http://localhost:8545"
echo "  RPC Endpoint (WS):   ws://localhost:8546"
echo "  BlockScout Explorer: http://localhost:4000"
echo "  Grafana Dashboard:   http://localhost:3000 (admin/admin)"
echo "  Prometheus:          http://localhost:9090"
echo ""
echo "Network Information:"
echo "  Network Name: Besu Network"
echo "  Chain ID: 1947"
echo "  Currency: Besu"
echo "  Consensus: QBFT"
echo "  Block Time: 2 seconds"
echo "  Gas Price: 0 (FREE)"
echo ""
echo "Step 12: Port-forwarding RPC and verifying it responds..."
# NodePort exposes RPC on :30545; port-forward to 8545 for tooling convenience.
kubectl port-forward -n ${NAMESPACE} svc/besu-rpc-internal 8545:8545 >/tmp/besu-pf.log 2>&1 &
PF_PID=$!
trap "kill ${PF_PID} 2>/dev/null || true" EXIT

# Wait up to 60s for the RPC to return a chainId
RPC_OK=0
for i in $(seq 1 60); do
    CHAIN_ID=$(curl -sS -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' 2>/dev/null \
        | jq -r '.result' 2>/dev/null)
    if [ "$CHAIN_ID" = "0x79b" ]; then
        echo "✓ RPC responding (chainId=1947)"
        RPC_OK=1
        break
    fi
    sleep 1
done
if [ "$RPC_OK" != "1" ]; then
    echo "✗ RPC did not respond in time. Aborting contract deploy."
    exit 1
fi

echo ""
echo "Step 13: Deploying Kanon contract to the Besu network..."
set +e
pushd kanon_contracts >/dev/null
if [ ! -d node_modules ]; then
    echo "  Installing kanon_contracts dependencies (first run)..."
    yarn install --frozen-lockfile
fi
BESU_LOCAL_RPC_URL=http://localhost:8545 npx hardhat run scripts/deploy-kanon.ts --network besu-local
DEPLOY_RC=$?
popd >/dev/null
set -e

if [ "$DEPLOY_RC" != "0" ]; then
    echo "✗ Kanon deployment failed"
    exit 1
fi

echo ""
echo "Admin Accounts:"
echo "  Check: keys/admin/ADMIN_ACCOUNTS.txt"
echo ""
echo "Kanon deployment record:"
echo "  kanon_contracts/deployments/1947.json"
echo ""
echo "Port-forward will be stopped when this script exits."
echo "To re-enable http://localhost:8545:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/besu-rpc-internal 8545:8545"
echo ""
echo "Useful commands:"
echo "  View logs: ./scripts/logs.sh"
echo "  Check status: ./scripts/status.sh"
echo "  Add deployer: ./scripts/add-deployer.sh <ADDRESS>"
echo "=================================================="
