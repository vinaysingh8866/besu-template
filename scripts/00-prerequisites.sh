#!/bin/bash

# Besu Network - Prerequisites Checker
# This script checks if all required tools are installed

set -e

echo "=================================================="
echo "  Besu Network - Prerequisites Checker"
echo "  Chain ID: 1947"
echo "=================================================="
echo ""

MISSING_TOOLS=0

# Check Docker
echo -n "Checking Docker... "
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    echo "✓ Found (version $DOCKER_VERSION)"
else
    echo "✗ Not found"
    echo "  Install: https://docs.docker.com/desktop/install/mac-install/"
    MISSING_TOOLS=1
fi

# Check kubectl
echo -n "Checking kubectl... "
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || kubectl version --client -o json | grep gitVersion | cut -d'"' -f4)
    echo "✓ Found (version $KUBECTL_VERSION)"
else
    echo "✗ Not found"
    echo "  Install: brew install kubectl"
    MISSING_TOOLS=1
fi

# Check Kind
echo -n "Checking Kind... "
if command -v kind &> /dev/null; then
    KIND_VERSION=$(kind version | cut -d' ' -f2)
    echo "✓ Found (version $KIND_VERSION)"
else
    echo "✗ Not found"
    echo "  Install: brew install kind"
    MISSING_TOOLS=1
fi

# Check jq (for JSON processing)
echo -n "Checking jq... "
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version | cut -d'-' -f2)
    echo "✓ Found (version $JQ_VERSION)"
else
    echo "✗ Not found"
    echo "  Install: brew install jq"
    MISSING_TOOLS=1
fi

# Check openssl (for key generation)
echo -n "Checking openssl... "
if command -v openssl &> /dev/null; then
    OPENSSL_VERSION=$(openssl version | cut -d' ' -f2)
    echo "✓ Found (version $OPENSSL_VERSION)"
else
    echo "✗ Not found"
    echo "  Install: brew install openssl"
    MISSING_TOOLS=1
fi

echo ""
echo "=================================================="

if [ $MISSING_TOOLS -eq 0 ]; then
    echo "✓ All prerequisites are installed!"
    echo ""
    echo "Next steps:"
    echo "  1. Run: ./scripts/01-setup-kind-cluster.sh"
    echo "  2. Then: ./scripts/02-generate-node-keys.sh"
    exit 0
else
    echo "✗ Some tools are missing. Please install them and try again."
    exit 1
fi
