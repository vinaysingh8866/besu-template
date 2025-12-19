#!/bin/bash

# Besu Network - Status Check
# Shows the current status of all network components

set -e

NAMESPACE="besu-network"
RPC_URL="http://localhost:8545"

echo "=================================================="
echo "  Besu Network - Status Check"
echo "  Chain ID: 1947"
echo "=================================================="
echo ""

echo "Kubernetes Cluster:"
kubectl cluster-info | head -1
echo ""

echo "Pods Status:"
kubectl get pods -n ${NAMESPACE} -o wide
echo ""

echo "Services:"
kubectl get svc -n ${NAMESPACE}
echo ""

echo "Storage:"
kubectl get pvc -n ${NAMESPACE}
echo ""

echo "Blockchain Information:"
echo "  Testing RPC endpoint at ${RPC_URL}..."

# Check if RPC is responding
if curl -s -X POST ${RPC_URL} \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    --connect-timeout 5 >/dev/null 2>&1; then

    echo "  ✓ RPC endpoint is responding"

    # Get chain ID
    CHAIN_ID=$(curl -s -X POST ${RPC_URL} \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | \
        jq -r '.result')
    echo "  Chain ID: $CHAIN_ID ($(printf "%d" $CHAIN_ID))"

    # Get latest block
    BLOCK_NUMBER=$(curl -s -X POST ${RPC_URL} \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
        jq -r '.result')
    echo "  Latest Block: $(printf "%d" $BLOCK_NUMBER)"

    # Get peer count
    PEER_COUNT=$(curl -s -X POST ${RPC_URL} \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' | \
        jq -r '.result')
    echo "  Peer Count: $(printf "%d" $PEER_COUNT)"

    # Get syncing status
    IS_SYNCING=$(curl -s -X POST ${RPC_URL} \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' | \
        jq -r '.result')
    if [ "$IS_SYNCING" == "false" ]; then
        echo "  Sync Status: ✓ Synced"
    else
        echo "  Sync Status: Syncing..."
    fi

    # Get gas price (should be 0)
    GAS_PRICE=$(curl -s -X POST ${RPC_URL} \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}' | \
        jq -r '.result')
    echo "  Gas Price: $(printf "%d" $GAS_PRICE) (FREE)"

else
    echo "  ✗ RPC endpoint not responding"
    echo "  Make sure the network is deployed and running"
fi

echo ""
echo "Access Points:"
echo "  RPC Endpoint (HTTP): http://localhost:8545"
echo "  RPC Endpoint (WS):   ws://localhost:8546"
echo "  BlockScout Explorer: http://localhost:4000"
echo "  Grafana Dashboard:   http://localhost:3000"
echo "  Prometheus:          http://localhost:9090"
echo ""

echo "Whitelisted Deployers:"
kubectl get configmap besu-rpc-config -n ${NAMESPACE} -o jsonpath='{.data.permissioning-config\.toml}' | grep "0x" || echo "  (none)"

echo ""
echo "=================================================="
