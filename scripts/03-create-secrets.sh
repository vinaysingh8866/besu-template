#!/bin/bash

# Besu Network - Create Kubernetes Secrets
# Creates secrets from generated node keys

set -e

KEYS_DIR="keys"
NAMESPACE="besu-network"

echo "=================================================="
echo "  Besu Network - Create Kubernetes Secrets"
echo "  Chain ID: 1947"
echo "=================================================="
echo ""

# Check if keys directory exists
if [ ! -d "${KEYS_DIR}" ]; then
    echo "✗ Keys directory not found!"
    echo "  Please run: ./scripts/02-generate-node-keys.sh"
    exit 1
fi

echo "Creating namespace: ${NAMESPACE}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Creating node key secrets..."

# Function to create a secret from node keys
create_node_secret() {
    local node_name=$1
    local secret_name=$2
    local key_dir="${KEYS_DIR}/${node_name}"

    echo -n "  Creating secret for ${node_name}... "

    kubectl create secret generic ${secret_name} \
        --from-file=key=${key_dir}/key \
        --from-file=key.pub=${key_dir}/key.pub \
        --namespace=${NAMESPACE} \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null

    echo "✓"
}

# Create secrets for all nodes
create_node_secret "bootnode" "besu-bootnode-keys"
create_node_secret "validator-0" "besu-validator-0-keys"
create_node_secret "validator-1" "besu-validator-1-keys"
create_node_secret "validator-2" "besu-validator-2-keys"
create_node_secret "validator-3" "besu-validator-3-keys"
create_node_secret "rpc" "besu-rpc-keys"

echo ""
echo "Creating BlockScout secrets..."

# Generate random password for PostgreSQL
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Generate random secret key base for BlockScout (needs to be 64 chars)
SECRET_KEY_BASE=$(openssl rand -hex 64)

# Create database URL
DATABASE_URL="postgresql://blockscout:${POSTGRES_PASSWORD}@blockscout-postgres:5432/blockscout"

echo -n "  Creating BlockScout secrets... "
kubectl create secret generic blockscout-secrets \
    --from-literal=postgres-password=${POSTGRES_PASSWORD} \
    --from-literal=secret-key-base=${SECRET_KEY_BASE} \
    --from-literal=database-url=${DATABASE_URL} \
    --namespace=${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "✓"

echo ""
echo "Creating Grafana secrets..."

# Default Grafana password (user can change later)
GRAFANA_PASSWORD="admin"

echo -n "  Creating Grafana secrets... "
kubectl create secret generic grafana-secrets \
    --from-literal=admin-password=${GRAFANA_PASSWORD} \
    --namespace=${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "✓"

echo ""
echo "=================================================="
echo "✓ All secrets created successfully!"
echo ""
echo "Created secrets:"
kubectl get secrets -n ${NAMESPACE}
echo ""
echo "Grafana login:"
echo "  Username: admin"
echo "  Password: ${GRAFANA_PASSWORD}"
echo ""
echo "⚠️  IMPORTANT: Change Grafana password after first login!"
echo ""
echo "Next step:"
echo "  Run: ./scripts/04-deploy-network.sh"
echo "=================================================="
