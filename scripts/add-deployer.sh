#!/bin/bash

# Besu Network - Add Contract Deployer
# Adds an Ethereum address to the contract deployment whitelist

set -e

NAMESPACE="besu-network"
CONFIG_DIR="config/besu"

if [ -z "$1" ]; then
    echo "Usage: $0 <ethereum-address>"
    echo ""
    echo "Example: $0 0x1234567890123456789012345678901234567890"
    echo ""
    echo "Current whitelisted deployers:"
    cat ${CONFIG_DIR}/permissioning-config.toml | grep "0x" || echo "  (none)"
    exit 1
fi

ADDRESS=$1

# Validate Ethereum address format
if [[ ! $ADDRESS =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo "✗ Invalid Ethereum address format!"
    echo "  Address must be 42 characters starting with 0x"
    exit 1
fi

echo "=================================================="
echo "  Besu Network - Add Contract Deployer"
echo "  Chain ID: 1947"
echo "=================================================="
echo ""
echo "Adding address: $ADDRESS"

# Check if address already exists
if grep -q "$ADDRESS" ${CONFIG_DIR}/permissioning-config.toml; then
    echo "⚠️  Address already whitelisted!"
    exit 0
fi

# Add address to permissioning config
sed -i.bak "/accounts-allowlist = \[/a\\
  \"$ADDRESS\",\
" ${CONFIG_DIR}/permissioning-config.toml

# Remove the last comma if it's before the closing bracket
sed -i.bak 's/,\([ ]*\]]/\1]]/g' ${CONFIG_DIR}/permissioning-config.toml

echo "✓ Address added to permissioning-config.toml"

# Update the ConfigMap in Kubernetes
echo "Updating Kubernetes ConfigMap..."
kubectl create configmap besu-rpc-config \
    --from-file=genesis.json=${CONFIG_DIR}/genesis.json \
    --from-file=permissioning-config.toml=${CONFIG_DIR}/permissioning-config.toml \
    --namespace=${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "✓ ConfigMap updated"

# Restart RPC pod to pick up changes
echo "Restarting RPC node to apply changes..."
kubectl rollout restart deployment/besu-rpc -n ${NAMESPACE}
kubectl rollout status deployment/besu-rpc -n ${NAMESPACE} --timeout=300s

echo ""
echo "=================================================="
echo "✓ Deployer added successfully!"
echo ""
echo "Address $ADDRESS can now deploy smart contracts."
echo ""
echo "Current whitelisted deployers:"
cat ${CONFIG_DIR}/permissioning-config.toml | grep "0x" || echo "  (none)"
echo "=================================================="
