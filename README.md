# Besu Network

A production-ready, permissioned blockchain network built on Hyperledger Besu with QBFT consensus.

## 🌟 Network Information

- **Network Name:** Besu Network
- **Chain ID:** 1947
- **Currency Symbol:** Besu
- **Consensus:** QBFT (Istanbul Byzantine Fault Tolerant)
- **Block Time:** 2 seconds
- **Gas Price:** 0 (FREE transactions)
- **Permissioning:** Contract deployment restricted to whitelisted accounts

## 🎯 Features

✅ **Zero gas transactions** - All transactions are completely free
✅ **Public RPC endpoint** - Anyone can use the network
✅ **Permissioned contract deployment** - Only whitelisted accounts can deploy contracts
✅ **Block Explorer** - BlockScout integration for transparency
✅ **Full monitoring** - Prometheus + Grafana dashboards
✅ **Production-grade** - Kubernetes-based, scalable architecture
✅ **Local development** - Kind cluster for testing
✅ **Cloud-ready** - Terraform templates for production deployment

## 📋 Prerequisites

- **macOS** (tested on macOS, adaptable for Linux)
- **Docker Desktop** - For containerization
- **kubectl** - Kubernetes CLI
- **Kind** - Kubernetes in Docker
- **jq** - JSON processor
- **openssl** - For key generation

Install prerequisites:
```bash
brew install docker kubectl kind jq openssl
```

## 🚀 Quick Start

### Complete Automated Deployment

Run everything with a single command:

```bash
chmod +x scripts/*.sh
./scripts/deploy-all.sh
```

This will:
1. Check prerequisites
2. Create Kind Kubernetes cluster
3. Generate node keys and admin accounts
4. Create Kubernetes secrets
5. Deploy the entire network

### Manual Step-by-Step Deployment

If you prefer to run each step manually:

```bash
# 1. Check prerequisites
./scripts/00-prerequisites.sh

# 2. Create Kind cluster
./scripts/01-setup-kind-cluster.sh

# 3. Generate keys and admin accounts
./scripts/02-generate-node-keys.sh

# 4. Create Kubernetes secrets
./scripts/03-create-secrets.sh

# 5. Deploy network
./scripts/04-deploy-network.sh
```

## 🔗 Access Points

Once deployed, access the network at:

- **RPC Endpoint (HTTP):** `http://localhost:8545`
- **RPC Endpoint (WebSocket):** `ws://localhost:8546`
- **BlockScout Explorer:** `http://localhost:4000`
- **Grafana Dashboard:** `http://localhost:3000` (admin/admin)
- **Prometheus:** `http://localhost:9090`

## 🔑 Admin Accounts

After deployment, check `keys/admin/ADMIN_ACCOUNTS.txt` for:
- 3 generated admin accounts
- Private keys and addresses
- These accounts can deploy smart contracts

**⚠️ IMPORTANT:** Keep these private keys secure!

## 📊 Network Architecture

```
┌─────────────────┐
│   RPC Node      │ ← Public endpoint (localhost:8545)
│   (Deployment)  │
└────────┬────────┘
         │
         ├─────────┬─────────┬─────────┬─────────┐
         │         │         │         │         │
    ┌────▼───┐┌───▼────┐┌───▼────┐┌───▼────┐┌───▼────┐
    │Bootnode││Validator││Validator││Validator││Validator│
    │  (1)   ││   (1)   ││   (2)   ││   (3)   ││   (4)   │
    └────────┘└────────┘└────────┘└────────┘└────────┘
                     QBFT Consensus

┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  BlockScout  │  │  Prometheus  │  │   Grafana    │
│  (Explorer)  │  │  (Metrics)   │  │ (Dashboard)  │
└──────────────┘  └──────────────┘  └──────────────┘
```

## 🛠️ Management Scripts

### View Status
```bash
./scripts/status.sh
```

### View Logs
```bash
./scripts/logs.sh
```

### Add Contract Deployer
```bash
./scripts/add-deployer.sh 0xYourEthereumAddress
```

### Reset Network (delete all data)
```bash
./scripts/reset-network.sh
```

### Complete Cleanup
```bash
./scripts/cleanup.sh
```

## 🧪 Testing the Network

### Using curl
```bash
# Get chain ID
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Get latest block
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Get gas price (should be 0)
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}'
```

### Using Metamask

1. Add custom network:
   - **Network Name:** Besu Network
   - **RPC URL:** `http://localhost:8545`
   - **Chain ID:** `1947`
   - **Currency Symbol:** `Besu`

2. Import one of the admin accounts from `keys/admin/ADMIN_ACCOUNTS.txt`

3. You can now deploy contracts!

## 📚 Documentation

Detailed guides are available in the `docs/` directory:

- **[Local Setup Guide](docs/00-LOCAL-SETUP.md)** - Complete local development setup
- **[Architecture Guide](docs/01-ARCHITECTURE.md)** - System architecture and design
- **[Permissioning Guide](docs/02-PERMISSIONING.md)** - Managing contract deployment whitelist
- **[Operations Guide](docs/03-OPERATIONS.md)** - Day-to-day operations
- **[Troubleshooting](docs/04-TROUBLESHOOTING.md)** - Common issues and solutions
- **[Production Deployment](docs/05-PRODUCTION-DEPLOY.md)** - Deploying to production

## 🚢 Production Deployment

The repository includes Terraform templates for production deployment on:

- **DigitalOcean** - `deployment/terraform/digitalocean/`
- **AWS Mumbai** - `deployment/terraform/india-providers/aws-mumbai/`
- **GCP Mumbai** - `deployment/terraform/india-providers/gcp-mumbai/`
- **Azure Pune** - `deployment/terraform/india-providers/azure-pune/`

See [Production Deployment Guide](docs/05-PRODUCTION-DEPLOY.md) for details.

## 🔒 Security Features

- **Permissioned contract deployment** - Only whitelisted accounts
- **Encrypted secrets** - Kubernetes secrets for all keys
- **Zero gas price** - Prevents economic attacks
- **Network policies** - Pod isolation in Kubernetes
- **RBAC** - Role-based access control
- **TLS/SSL ready** - For production endpoints

## 📦 Project Structure

```
besi_blockchain/
├── config/              # Network configuration
│   ├── besu/           # Genesis, permissioning
│   ├── blockscout/     # Explorer config
│   └── monitoring/     # Prometheus config
├── kubernetes/         # Kubernetes manifests
│   ├── bootnode/
│   ├── validators/
│   ├── rpc/
│   ├── blockscout/
│   ├── monitoring/
│   └── storage/
├── scripts/            # Management scripts
├── local-k8s/          # Kind cluster config
├── deployment/         # Production deployment
│   ├── terraform/      # Infrastructure as Code
│   └── kubernetes/     # Production K8s configs
├── docs/               # Documentation
├── keys/               # Generated keys (gitignored)
└── data/               # Blockchain data (gitignored)
```

## 🤝 Contributing

This is a private blockchain network. For issues or improvements:

1. Review documentation in `docs/`
2. Check existing configuration
3. Test changes locally before production

## 📝 License

Private blockchain network. All rights reserved.

## 🆘 Support

For help:
- Check [Troubleshooting Guide](docs/04-TROUBLESHOOTING.md)
- Review logs: `./scripts/logs.sh`
- Check status: `./scripts/status.sh`
- Consult [Hyperledger Besu Documentation](https://besu.hyperledger.org/)

---

**Besu Network** - Built with ❤️ using Hyperledger Besu
