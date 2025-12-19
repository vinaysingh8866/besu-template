#!/bin/bash

# Besu Network - Reset Network
# Deletes all blockchain data and restarts from genesis

set -e

NAMESPACE="besu-network"

echo "=================================================="
echo "  Besu Network - Reset Network"
echo "  Chain ID: 1947"
echo "=================================================="
echo ""
echo "⚠️  WARNING: This will delete ALL blockchain data!"
echo "   All transactions and blocks will be lost."
echo ""
read -p "Are you sure you want to reset the network? (yes/NO): " -r
echo

if [ "$REPLY" != "yes" ]; then
    echo "Reset cancelled."
    exit 0
fi

echo "Deleting all pods..."
kubectl delete pods --all -n ${NAMESPACE}

echo ""
echo "Deleting all PVCs (this will delete blockchain data)..."
kubectl delete pvc --all -n ${NAMESPACE}

echo ""
echo "Waiting for pods to terminate..."
kubectl wait --for=delete pod --all -n ${NAMESPACE} --timeout=300s || true

echo ""
echo "Redeploying network..."
./scripts/04-deploy-network.sh

echo ""
echo "=================================================="
echo "✓ Network reset complete!"
echo "  The blockchain has been reset to genesis block."
echo "=================================================="
