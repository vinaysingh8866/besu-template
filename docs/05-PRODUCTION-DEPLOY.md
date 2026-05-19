# Besu Network - Production Deployment

Guide for deploying Besu Network to production environments.

## Overview

The production deployment uses:
- **Kubernetes** for orchestration (same as local)
- **Terraform** for infrastructure provisioning
- **Cloud providers** for compute and storage
- **Managed services** where beneficial

## Supported Cloud Providers

### India-based Deployments (Recommended)

1. **AWS Mumbai Region** (`ap-south-1`)
   - Location: `deployment/terraform/india-providers/aws-mumbai/`
   - Services: EKS, EBS, S3

2. **GCP Mumbai Region** (`asia-south1`)
   - Location: `deployment/terraform/india-providers/gcp-mumbai/`
   - Services: GKE, Persistent Disks, Cloud Storage

3. **Azure Pune Region** (`centralindia`)
   - Location: `deployment/terraform/india-providers/azure-pune/`
   - Services: AKS, Managed Disks, Blob Storage

### Global Deployment

**DigitalOcean** (Global)
- Location: `deployment/terraform/digitalocean/`
- Services: DOKS, Block Storage, Spaces
- Cost-effective for startups

## Deployment Architecture (Production)

```
                    ┌─────────────────┐
                    │   Load Balancer  │
                    │   (Cloud LB)     │
                    └────────┬─────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────▼────┐         ┌────▼────┐        ┌────▼────┐
    │ RPC Pod │         │ RPC Pod │        │ RPC Pod │
    │    1    │         │    2    │        │    3    │
    └────┬────┘         └────┬────┘        └────┬────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────▼────┐         ┌────▼────┐        ┌────▼────┐
    │Validator│         │Validator│        │Validator│
    │    1    │◄────────►    2    │◄───────►    3    │
    └────┬────┘         └────┬────┘        └────┬────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                        ┌────▼────┐
                        │Validator│
                        │    4    │
                        └─────────┘

┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│   BlockScout   │  │   Prometheus   │  │    Grafana     │
│  + PostgreSQL  │  │   + Storage    │  │  + Dashboards  │
└────────────────┘  └────────────────┘  └────────────────┘
```

## Differences from Local Setup

| Component | Local (Kind) | Production (Cloud) |
|-----------|-------------|-------------------|
| **Cluster** | Kind (Docker) | Managed K8s (EKS/GKE/AKS/DOKS) |
| **Storage** | Local path | Cloud block storage (SSD) |
| **Load Balancer** | NodePort | Cloud LB (Layer 4/7) |
| **SSL/TLS** | None | cert-manager + Let's Encrypt |
| **Secrets** | K8s secrets | Sealed Secrets / Vault |
| **Monitoring** | In-cluster | Separate + Cloud monitoring |
| **Backups** | Manual | Automated to cloud storage |
| **HA** | Single node | Multi-AZ, auto-healing |
| **Scaling** | Manual | Auto-scaling groups |

## Prerequisites (Production)

### 1. Cloud Account Setup

**For DigitalOcean:**
```bash
# Install doctl
brew install doctl

# Authenticate
doctl auth init

# Create API token
# Visit: https://cloud.digitalocean.com/account/api/tokens
```

**For AWS:**
```bash
# Install AWS CLI
brew install awscli

# Configure
aws configure
```

**For GCP:**
```bash
# Install gcloud
brew install google-cloud-sdk

# Authenticate
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

**For Azure:**
```bash
# Install Azure CLI
brew install azure-cli

# Login
az login
```

### 2. Domain Name

You need a domain for:
- RPC endpoint: `rpc.yourdomain.com`
- Explorer: `explorer.yourdomain.com`
- Monitoring: `monitoring.yourdomain.com`

Register domain with:
- Namecheap, GoDaddy (international)
- BigRock, HostGator India (India-specific)

### 3. SSL Certificates

Using cert-manager + Let's Encrypt (automatic):
- Free SSL certificates
- Auto-renewal
- Supports wildcard certificates

### 4. Terraform Setup

```bash
# Install Terraform
brew install terraform

# Verify installation
terraform --version
```

## Deployment Process (Overview)

### Phase 1: Infrastructure Setup

1. **Configure Terraform variables**
   ```bash
   cd deployment/terraform/digitalocean/
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Plan deployment**
   ```bash
   terraform plan
   ```

4. **Apply infrastructure**
   ```bash
   terraform apply
   ```

This creates:
- Kubernetes cluster
- Load balancer
- Storage volumes
- Networking (VPC, firewall)
- DNS records (if configured)

### Phase 2: Kubernetes Setup

1. **Get cluster credentials**
   ```bash
   # DigitalOcean
   doctl kubernetes cluster kubeconfig save <cluster-name>

   # AWS
   aws eks update-kubeconfig --name <cluster-name>

   # GCP
   gcloud container clusters get-credentials <cluster-name>

   # Azure
   az aks get-credentials --resource-group <rg> --name <cluster-name>
   ```

2. **Install cert-manager**
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

3. **Install sealed-secrets controller**
   ```bash
   kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
   ```

4. **Create sealed secrets**
   ```bash
   # Install kubeseal CLI
   brew install kubeseal

   # Seal node keys
   kubectl create secret generic besu-bootnode-keys \
     --from-file=keys/bootnode/key \
     --from-file=keys/bootnode/key.pub \
     --dry-run=client -o yaml | \
     kubeseal -o yaml > kubernetes/secrets/sealed-bootnode.yaml

   # Apply sealed secrets
   kubectl apply -f kubernetes/secrets/
   ```

### Phase 3: Network Deployment

1. **Deploy blockchain nodes**
   ```bash
   # Using production manifests
   kubectl apply -f deployment/kubernetes/production/
   ```

2. **Configure DNS**
   - Point `rpc.yourdomain.com` to Load Balancer IP
   - Point `explorer.yourdomain.com` to Load Balancer IP
   - Point `monitoring.yourdomain.com` to Load Balancer IP

3. **Verify SSL certificates**
   ```bash
   kubectl get certificate -n besu-network
   ```

4. **Test endpoints**
   ```bash
   curl https://rpc.yourdomain.com -X POST \
     -H "Content-Type: application/json" \
     --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
   ```

## Security Hardening (Production)

### 1. Network Security

- **Firewall rules** (restrict RPC to known IPs if needed)
- **DDoS protection** (Cloud LB features)
- **Rate limiting** (Nginx Ingress)
- **Network policies** (Pod isolation)

### 2. Secret Management

- **Use HashiCorp Vault** for production secrets
- **Rotate keys** regularly
- **Backup keys** securely (encrypted)

### 3. Access Control

- **RBAC** for Kubernetes access
- **Bastion host** for SSH access
- **VPN** for administrative access
- **Audit logging** enabled

### 4. Monitoring & Alerting

- **Prometheus** for metrics
- **Grafana** for visualization
- **Alertmanager** for notifications
- **PagerDuty/Slack** integration

## Backup Strategy

### Automated Backups

1. **Blockchain data** (daily)
   - Snapshot PersistentVolumes
   - Upload to cloud storage
   - Retention: 30 days

2. **PostgreSQL** (BlockScout)
   - pg_dump daily
   - Upload to cloud storage
   - Retention: 30 days

3. **Configuration**
   - Git repository (encrypted secrets)
   - Backup Terraform state

### Backup Script Example

```bash
#!/bin/bash
# Production backup script (runs as CronJob)

DATE=$(date +%Y%m%d)
BACKUP_DIR="/backups"
S3_BUCKET="s3://Besu-network-backups"

# Backup validator data
kubectl exec besu-validator-0 -n besu-network -- \
  tar czf /data/backup-${DATE}.tar.gz /data/database

# Upload to S3
aws s3 cp /data/backup-${DATE}.tar.gz ${S3_BUCKET}/validator-0/

# Backup PostgreSQL
kubectl exec blockscout-postgres-0 -n besu-network -- \
  pg_dump -U blockscout blockscout > blockscout-${DATE}.sql

aws s3 cp blockscout-${DATE}.sql ${S3_BUCKET}/blockscout/

# Cleanup old backups (keep 30 days)
find ${BACKUP_DIR} -name "*.tar.gz" -mtime +30 -delete
```

## Scaling

### Vertical Scaling (More resources)

```bash
# Edit node pool
# Increase CPU/Memory per node

# For RPC nodes
kubectl edit deployment besu-rpc -n besu-network
# Update resources.requests and resources.limits
```

### Horizontal Scaling (More pods)

```bash
# Scale RPC nodes
kubectl scale deployment besu-rpc --replicas=5 -n besu-network

# Note: Validators should stay at 4 for QBFT consensus
```

### Auto-scaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: besu-rpc-hpa
  namespace: besu-network
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: besu-rpc
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

## Cost Optimization

### 1. Right-sizing

- Start small, scale as needed
- Monitor actual usage
- Use spot instances for non-critical workloads

### 2. Storage Optimization

- Enable pruning: `--pruning-enabled`
- Use cheaper storage for non-validator nodes
- Archive old data

### 3. Reserved Instances

- For predictable workloads
- 30-70% cost savings
- 1-3 year commitments

## Monitoring Production

### Key Metrics

1. **Blockchain Health**
   - Block height
   - Peer count
   - Sync status
   - Transaction pool size

2. **Infrastructure**
   - CPU/Memory usage
   - Disk I/O
   - Network bandwidth
   - Pod restarts

3. **Application**
   - RPC request rate
   - RPC error rate
   - Response time
   - Active connections

### Alerting Rules

```yaml
# Example Prometheus alert rules
groups:
  - name: besu
    rules:
      - alert: NodeDown
        expr: up{job="besu-validators"} == 0
        for: 5m
        annotations:
          summary: "Besu node is down"

      - alert: SyncStopped
        expr: increase(besu_blockchain_height[5m]) == 0
        for: 10m
        annotations:
          summary: "Blockchain sync has stopped"

      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        annotations:
          summary: "Pod memory usage > 90%"
```

## Disaster Recovery

### Recovery Scenarios

1. **Single pod failure** → Auto-heals (K8s restart)
2. **Node failure** → Auto-migrates to healthy node
3. **AZ failure** → Multi-AZ deployment handles
4. **Region failure** → Restore from backup in new region
5. **Data corruption** → Restore from latest backup

### Recovery Procedure

```bash
# 1. Stop affected components
kubectl delete -f deployment/kubernetes/production/rpc/

# 2. Restore from backup
aws s3 cp s3://backups/latest.tar.gz .
tar xzf latest.tar.gz

# 3. Create new PVC with restored data
kubectl apply -f restored-pvc.yaml

# 4. Redeploy components
kubectl apply -f deployment/kubernetes/production/rpc/

# 5. Verify
./scripts/status.sh
```

## Maintenance Windows

### Zero-downtime Updates

1. **RPC nodes** (can update without downtime)
   ```bash
   kubectl set image deployment/besu-rpc besu=hyperledger/besu:NEW_VERSION -n besu-network
   kubectl rollout status deployment/besu-rpc -n besu-network
   ```

2. **Validators** (requires coordination)
   - Update one at a time
   - Wait for consensus before next
   - Total time: ~30 minutes for all 4

3. **BlockScout**
   - Update database schema
   - Rolling update deployment

## Compliance & Auditing

### Logging

- **Centralized logging** (ELK/EFK stack)
- **Audit trails** for all admin actions
- **Retention policy** (comply with regulations)

### Access Logs

```bash
# Enable RPC access logging
# Add to RPC container args:
--logging=INFO
--log-level=INFO

# Forward to centralized system
# Use Fluentd/Fluent Bit
```

## Troubleshooting Production

### Common Issues

1. **High RPC latency**
   - Scale RPC pods
   - Check database performance
   - Optimize queries

2. **Validator out of sync**
   - Check peer connections
   - Verify network connectivity
   - Check disk I/O

3. **Certificate renewal failed**
   - Check cert-manager logs
   - Verify DNS configuration
   - Check Let's Encrypt rate limits

## Next Steps

1. **Choose cloud provider** based on:
   - Location requirements (India?)
   - Budget
   - Existing infrastructure

2. **Configure Terraform** for your provider

3. **Test in staging** environment first

4. **Plan migration** from local to production

5. **Set up monitoring** and alerting

6. **Document runbooks** for your team

## Resources

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Besu Production Checklist](https://besu.hyperledger.org/en/stable/HowTo/Deploy/Production/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)

---

**Note:** Full Terraform configurations will be added based on final cloud provider selection.
