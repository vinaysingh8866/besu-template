#!/bin/bash

# Besu Network - Cleanup
# Completely removes the network and Kind cluster

set -e

CLUSTER_NAME="Besu-network"
NAMESPACE="besu-network"

echo "=================================================="
echo "  Besu Network - Cleanup"
echo "  Chain ID: 1947"
echo "=================================================="
echo ""
echo "⚠️  WARNING: This will:"
echo "   - Delete the Kubernetes cluster"
echo "   - Remove all blockchain data"
echo "   - Remove all monitoring data"
echo ""
echo "   Generated keys in keys/ directory will be preserved."
echo ""
read -p "Are you sure you want to cleanup everything? (yes/NO): " -r
echo

if [ "$REPLY" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo "Deleting Kind cluster..."
kind delete cluster --name ${CLUSTER_NAME}

echo ""
echo "Cleaning up local data directory..."
rm -rf data/*

echo ""
echo "=================================================="
echo "✓ Cleanup complete!"
echo ""
echo "Preserved:"
echo "  - Configuration files in config/"
echo "  - Node keys in keys/"
echo "  - Kubernetes manifests in kubernetes/"
echo ""
echo "To start fresh:"
echo "  1. Run: ./scripts/01-setup-kind-cluster.sh"
echo "  2. Then: ./scripts/03-create-secrets.sh"
echo "  3. Finally: ./scripts/04-deploy-network.sh"
echo ""
echo "To generate new keys:"
echo "  Run: ./scripts/02-generate-node-keys.sh"
echo "=================================================="
