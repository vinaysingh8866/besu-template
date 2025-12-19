#!/bin/bash

# Besu Network - Node Key Generation
# Generates private keys for all Besu nodes and admin accounts

set -e

KEYS_DIR="keys"
CONFIG_DIR="config/besu"

echo "=================================================="
echo "  Besu Network - Node Key Generation"
echo "  Chain ID: 1947"
echo "=================================================="
echo ""

# Create keys directory
mkdir -p ${KEYS_DIR}/{bootnode,validator-{0..3},rpc,admin}

echo "Pulling Besu Docker image for key generation..."
docker pull hyperledger/besu:latest

echo ""
echo "Generating keys for nodes..."

# Function to generate a key pair
generate_key() {
    local node_type=$1
    local node_name=$2
    local key_dir="${KEYS_DIR}/${node_name}"

    echo -n "  Generating keys for ${node_type}... "

    docker run --rm \
        -v "$(pwd)/${key_dir}:/data" \
        hyperledger/besu:latest \
        --data-path=/data \
        public-key export --to=/data/key.pub \
        >/dev/null 2>&1

    # Get the public key (enode)
    PUBKEY=$(cat ${key_dir}/key.pub)
    echo "✓"
    echo "    Public key: ${PUBKEY}"
}

# Generate keys for each node
generate_key "Bootnode" "bootnode"
generate_key "Validator 0" "validator-0"
generate_key "Validator 1" "validator-1"
generate_key "Validator 2" "validator-2"
generate_key "Validator 3" "validator-3"
generate_key "RPC Node" "rpc"

echo ""
echo "Generating admin accounts for contract deployment..."

# Generate 3 admin accounts
for i in {1..3}; do
    echo -n "  Generating Admin Account ${i}... "

    # Generate a private key using openssl
    PRIVATE_KEY=$(openssl rand -hex 32)

    # Use Besu to derive the address from the private key
    echo ${PRIVATE_KEY} > ${KEYS_DIR}/admin/admin-${i}.key

    # Create a temporary key file for Besu
    docker run --rm \
        -v "$(pwd)/${KEYS_DIR}/admin:/data" \
        hyperledger/besu:latest \
        --data-path=/data/temp${i} \
        --node-private-key-file=/data/admin-${i}.key \
        public-key export-address --to=/data/admin-${i}.address \
        >/dev/null 2>&1

    ADDRESS=$(cat ${KEYS_DIR}/admin/admin-${i}.address)
    echo "✓"
    echo "    Address: ${ADDRESS}"
    echo "    Private Key: ${PRIVATE_KEY}"

    # Clean up temp directory
    rm -rf ${KEYS_DIR}/admin/temp${i}
done

echo ""
echo "Creating static-nodes.json..."

# Read public keys
BOOTNODE_PUBKEY=$(cat ${KEYS_DIR}/bootnode/key.pub)
VALIDATOR0_PUBKEY=$(cat ${KEYS_DIR}/validator-0/key.pub)
VALIDATOR1_PUBKEY=$(cat ${KEYS_DIR}/validator-1/key.pub)
VALIDATOR2_PUBKEY=$(cat ${KEYS_DIR}/validator-2/key.pub)
VALIDATOR3_PUBKEY=$(cat ${KEYS_DIR}/validator-3/key.pub)

# Create static-nodes.json
cat > ${CONFIG_DIR}/static-nodes.json <<EOF
[
  "enode://${BOOTNODE_PUBKEY}@besu-bootnode-0.besu-bootnode.besu-network.svc.cluster.local:30303",
  "enode://${VALIDATOR0_PUBKEY}@besu-validator-0.besu-validator.besu-network.svc.cluster.local:30303",
  "enode://${VALIDATOR1_PUBKEY}@besu-validator-1.besu-validator.besu-network.svc.cluster.local:30303",
  "enode://${VALIDATOR2_PUBKEY}@besu-validator-2.besu-validator.besu-network.svc.cluster.local:30303",
  "enode://${VALIDATOR3_PUBKEY}@besu-validator-3.besu-validator.besu-network.svc.cluster.local:30303"
]
EOF

echo "✓ static-nodes.json created"

echo ""
echo "Updating genesis.json with validator addresses..."

# Extract validator addresses
VALIDATOR_ADDRESSES=""
for i in {0..3}; do
    docker run --rm \
        -v "$(pwd)/${KEYS_DIR}/validator-${i}:/data" \
        hyperledger/besu:latest \
        --data-path=/data \
        public-key export-address --to=/data/address \
        >/dev/null 2>&1

    ADDR=$(cat ${KEYS_DIR}/validator-${i}/address)
    if [ -z "$VALIDATOR_ADDRESSES" ]; then
        VALIDATOR_ADDRESSES="\"${ADDR}\""
    else
        VALIDATOR_ADDRESSES="${VALIDATOR_ADDRESSES}, \"${ADDR}\""
    fi
done

# Update genesis.json with validator addresses in extraData
# For QBFT, extraData format: 0x + vanity(64) + validators + round(8) + seals
VANITY="0000000000000000000000000000000000000000000000000000000000000000"

# Build validator list (concatenated addresses without 0x)
VALIDATOR_LIST=""
for i in {0..3}; do
    ADDR=$(cat ${KEYS_DIR}/validator-${i}/address | sed 's/0x//')
    VALIDATOR_LIST="${VALIDATOR_LIST}${ADDR}"
done

# Calculate length and create proper extraData
VALIDATOR_COUNT=4
LENGTH_BYTES=$(printf "%02x" $((VALIDATOR_COUNT * 20)))
ROUND="0000000000000000"
SEALS="c0"  # Empty seals

EXTRA_DATA="0x${VANITY}${LENGTH_BYTES}${VALIDATOR_LIST}${ROUND}${SEALS}"

# Update genesis.json
jq --arg extraData "$EXTRA_DATA" '.extraData = $extraData' ${CONFIG_DIR}/genesis.json > ${CONFIG_DIR}/genesis.json.tmp
mv ${CONFIG_DIR}/genesis.json.tmp ${CONFIG_DIR}/genesis.json

echo "✓ genesis.json updated with validator addresses"

echo ""
echo "Updating permissioning config with admin accounts..."

# Update permissioning-config.toml with admin addresses
ADMIN_ADDRESSES=""
for i in {1..3}; do
    ADDR=$(cat ${KEYS_DIR}/admin/admin-${i}.address)
    if [ -z "$ADMIN_ADDRESSES" ]; then
        ADMIN_ADDRESSES="  \"${ADDR}\""
    else
        ADMIN_ADDRESSES="${ADMIN_ADDRESSES},\n  \"${ADDR}\""
    fi
done

cat > ${CONFIG_DIR}/permissioning-config.toml <<EOF
# Besu Network Permissioning Configuration
# This file controls who can deploy smart contracts on the network

# Accounts allowed to deploy smart contracts
# Anyone can send transactions, but only these accounts can deploy contracts
accounts-allowlist = [
$(echo -e ${ADMIN_ADDRESSES})
]

# Node permissioning (optional - can restrict which nodes can join)
# nodes-allowlist = []
EOF

echo "✓ permissioning-config.toml updated"

echo ""
echo "Creating admin accounts summary..."

cat > ${KEYS_DIR}/admin/ADMIN_ACCOUNTS.txt <<EOF
Besu Network - Admin Accounts
Chain ID: 1947

These accounts are whitelisted to deploy smart contracts on the Besu Network.
Anyone can send transactions, but only these accounts can deploy contracts.

IMPORTANT: Keep these private keys secure!

EOF

for i in {1..3}; do
    ADDR=$(cat ${KEYS_DIR}/admin/admin-${i}.address)
    PRIVKEY=$(cat ${KEYS_DIR}/admin/admin-${i}.key)

    cat >> ${KEYS_DIR}/admin/ADMIN_ACCOUNTS.txt <<EOF
Admin Account ${i}:
  Address:     ${ADDR}
  Private Key: 0x${PRIVKEY}

EOF
done

echo "✓ Admin accounts summary created at ${KEYS_DIR}/admin/ADMIN_ACCOUNTS.txt"

echo ""
echo "=================================================="
echo "✓ All keys and accounts generated successfully!"
echo ""
echo "Summary:"
echo "  - Bootnode: 1 key"
echo "  - Validators: 4 keys"
echo "  - RPC Node: 1 key"
echo "  - Admin Accounts: 3 accounts"
echo ""
echo "Admin Accounts (can deploy contracts):"
for i in {1..3}; do
    ADDR=$(cat ${KEYS_DIR}/admin/admin-${i}.address)
    echo "  ${i}. ${ADDR}"
done
echo ""
echo "⚠️  IMPORTANT: Keys are stored in ${KEYS_DIR}/ directory"
echo "    Keep these keys secure and DO NOT commit to git!"
echo ""
echo "Next step:"
echo "  Run: ./scripts/03-create-secrets.sh"
echo "=================================================="
