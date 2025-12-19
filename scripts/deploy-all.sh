#!/bin/bash

# Besu Network - Complete Deployment
# Runs all deployment steps in order

set -e

echo "=================================================="
echo "  Besu Network - Complete Deployment"
echo "  Chain ID: 1947"
echo "=================================================="
echo ""
echo "This script will:"
echo "  1. Check prerequisites"
echo "  2. Create Kind cluster"
echo "  3. Generate node keys and admin accounts"
echo "  4. Create Kubernetes secrets"
echo "  5. Deploy the network"
echo ""
read -p "Continue? (Y/n): " -r
echo

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Make all scripts executable
chmod +x scripts/*.sh

echo ""
echo "Step 1/5: Checking prerequisites..."
./scripts/00-prerequisites.sh

echo ""
echo "Step 2/5: Setting up Kind cluster..."
./scripts/01-setup-kind-cluster.sh

echo ""
echo "Step 3/5: Generating node keys and admin accounts..."
./scripts/02-generate-node-keys.sh

echo ""
echo "Step 4/5: Creating Kubernetes secrets..."
./scripts/03-create-secrets.sh

echo ""
echo "Step 5/5: Deploying network..."
./scripts/04-deploy-network.sh

echo ""
echo "=================================================="
echo "✓ Complete deployment finished!"
echo ""
echo "Your Besu Network is ready!"
echo ""
echo "📝 Admin Accounts:"
echo "   Check keys/admin/ADMIN_ACCOUNTS.txt for deployer addresses"
echo ""
echo "🔗 Access Points:"
echo "   RPC:       http://localhost:8545"
echo "   Explorer:  http://localhost:4000"
echo "   Grafana:   http://localhost:3000"
echo ""
echo "📚 Documentation:"
echo "   See docs/ directory for guides"
echo "=================================================="
