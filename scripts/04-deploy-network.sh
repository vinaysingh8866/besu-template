#!/bin/bash

# Besu Network - Deploy Network
# Deploys all Besu nodes, BlockScout, and monitoring

set -e

NAMESPACE="besu-network"

echo "=================================================="
echo "  Besu Network - Deploy Network"
echo "  Chain ID: 1947"
echo "=================================================="
echo ""

# Check if namespace exists
if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
    echo "✗ Namespace '${NAMESPACE}' not found!"
    echo "  Please run: ./scripts/03-create-secrets.sh"
    exit 1
fi

echo "Step 1: Deploying storage class..."
kubectl apply -f kubernetes/storage/local-storage.yaml
echo "✓ Storage class deployed"

echo ""
echo "Step 2: Deploying bootnode..."
kubectl apply -f kubernetes/bootnode/
echo "✓ Bootnode deployed"

echo "  Waiting for bootnode to be ready..."
kubectl wait --for=condition=ready pod -l app=besu-bootnode -n ${NAMESPACE} --timeout=300s

echo ""
echo "Step 3: Deploying validators..."
kubectl apply -f kubernetes/validators/
echo "✓ Validators deployed"

echo "  Waiting for validators to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l app=besu-validator -n ${NAMESPACE} --timeout=600s

echo ""
echo "Step 4: Deploying RPC node..."
kubectl apply -f kubernetes/rpc/
echo "✓ RPC node deployed"

echo "  Waiting for RPC node to be ready..."
kubectl wait --for=condition=ready pod -l app=besu-rpc -n ${NAMESPACE} --timeout=300s

echo ""
echo "Step 5: Deploying PostgreSQL for BlockScout..."
kubectl apply -f kubernetes/blockscout/postgres-statefulset.yaml
echo "✓ PostgreSQL deployed"

echo "  Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=blockscout-postgres -n ${NAMESPACE} --timeout=300s

echo ""
echo "Step 6: Deploying Redis for BlockScout..."
kubectl apply -f kubernetes/blockscout/redis-deployment.yaml
echo "✓ Redis deployed"

echo "  Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=blockscout-redis -n ${NAMESPACE} --timeout=180s

echo ""
echo "Step 7: Deploying BlockScout..."
kubectl apply -f kubernetes/blockscout/blockscout-deployment.yaml
echo "✓ BlockScout deployed"

echo "  Waiting for BlockScout to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l app=blockscout -n ${NAMESPACE} --timeout=600s || true

echo ""
echo "Step 8: Deploying Prometheus..."
kubectl apply -f kubernetes/monitoring/prometheus/deployment.yaml
echo "✓ Prometheus deployed"

echo "  Waiting for Prometheus to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus -n ${NAMESPACE} --timeout=300s

echo ""
echo "Step 9: Deploying Grafana..."
kubectl apply -f kubernetes/monitoring/grafana/deployment.yaml
echo "✓ Grafana deployed"

echo "  Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app=grafana -n ${NAMESPACE} --timeout=300s

echo ""
echo "=================================================="
echo "✓ Besu Network deployed successfully!"
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
echo "Testing the RPC endpoint:"
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  2>/dev/null | jq . || echo "  (RPC endpoint will be available shortly)"
echo ""
echo "Useful commands:"
echo "  View logs: ./scripts/logs.sh"
echo "  Check status: ./scripts/status.sh"
echo "  Add deployer: ./scripts/add-deployer.sh <ADDRESS>"
echo "=================================================="
