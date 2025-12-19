#!/bin/bash

# Besu Network - Kind Cluster Setup
# Creates a local Kubernetes cluster using Kind

set -e

CLUSTER_NAME="Besu-network"
CONFIG_FILE="local-k8s/kind-config.yaml"

echo "=================================================="
echo "  Besu Network - Kind Cluster Setup"
echo "  Chain ID: 1947"
echo "=================================================="
echo ""

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "⚠️  Cluster '${CLUSTER_NAME}' already exists."
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing cluster..."
        kind delete cluster --name ${CLUSTER_NAME}
    else
        echo "Using existing cluster."
        exit 0
    fi
fi

echo "Creating Kind cluster with config: ${CONFIG_FILE}"
kind create cluster --config ${CONFIG_FILE}

echo ""
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo ""
echo "Installing local-path-provisioner for storage..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

echo ""
echo "Setting local-path as default storage class..."
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo ""
echo "=================================================="
echo "✓ Kind cluster '${CLUSTER_NAME}' is ready!"
echo ""
echo "Cluster info:"
kubectl cluster-info
echo ""
echo "Nodes:"
kubectl get nodes
echo ""
echo "Next step:"
echo "  Run: ./scripts/02-generate-node-keys.sh"
echo "=================================================="
