# Paragon Helm Charts Deployment Guide

## Overview

This guide covers deploying Paragon using Helm charts directly on Kubernetes. This approach is an alternative to using Terraform workspaces for AWS, Azure, or GCP deployments.

## Prerequisites

- Kubernetes cluster with kubectl access
- Helm 3.x installed
- A default StorageClass configured in your cluster
- Docker registry credentials for pulling Paragon images

### Infrastructure Prerequisites

Before deploying Paragon, install these core infrastructure components:

#### 1. NGINX Ingress Controller

Required for routing external traffic to your Paragon services:

```sh
# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install nginx ingress controller (default for most cloud providers)
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# Certain providers may require or benefit from custom annotations. e.g.
# for AWS EKS, you may want to use Network Load Balancer:
# helm install ingress-nginx ingress-nginx/ingress-nginx \
#   --namespace ingress-nginx \
#   --create-namespace \
#   --set controller.service.type=LoadBalancer \
#   --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb"
```

#### 2. cert-manager (for SSL Certificates)

Required for automatic SSL certificate management with Let's Encrypt:

```sh
# Add the cert-manager repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true
```

### DNS Configuration

After installing the infrastructure components and deploying Paragon, configure your DNS:

1. **Get the Load Balancer endpoint**:
   ```sh
   kubectl get service --namespace ingress-nginx ingress-nginx-controller --output wide
   ```

2. **Set up DNS records** pointing to the load balancer hostname:

   **Option A: Wildcard CNAME (Recommended)**
   ```
   *.<your-domain>                 CNAME   <load-balancer-hostname>
   ```
   
   **Note**: If using Cloudflare, ensure DNS-only mode (gray cloud) for proper Let's Encrypt certificate validation.
   
   **Option B: Individual CNAMEs**
   ```
   account.<your-domain>           CNAME   <load-balancer-hostname>
   dashboard.<your-domain>         CNAME   <load-balancer-hostname>
   cerberus.<your-domain>          CNAME   <load-balancer-hostname>
   # ... etc for all services
   ```

   **For the naked/apex domain** (optional):
   ```
   # AWS Route 53 (recommended for AWS)
   <your-domain>                   ALIAS   <load-balancer-hostname>
   
   # Cloudflare - DNS-only mode (not proxied!)
   <your-domain>                   CNAME   <load-balancer-hostname>  (DNS-only, gray cloud)
   
   # Traditional DNS providers - use A record with IP
   <your-domain>                   A       <load-balancer-ip>
   ```

   **⚠️ Important for Cloudflare users**: If using Cloudflare, make sure to use **DNS-only mode** (gray cloud icon) rather than proxied mode (orange cloud). Proxied mode will break Let's Encrypt certificate validation since Cloudflare terminates TLS at their edge instead of your ingress controller.

3. **Configure PARAGON_DOMAIN environment variable** in your values.yaml:
   ```yaml
   global:
     env:
       PARAGON_DOMAIN: "your-domain.com"
   ```

The ingresses will automatically use `<service-name>.<PARAGON_DOMAIN>` as hostnames when PARAGON_DOMAIN is set.

### Verify Infrastructure Setup

Before deploying Paragon, verify your infrastructure is ready:

```sh
# Check nginx ingress controller
kubectl get pods -n ingress-nginx
kubectl get service -n ingress-nginx ingress-nginx-controller

# Check cert-manager
kubectl get pods -n cert-manager
kubectl get clusterissuer  # Should show letsencrypt-prod after bootstrap deployment

# Check storage class
kubectl get storageclass
```

## Setup

### 1. Prepare Charts

First, prepare the charts for Kubernetes deployment:

```sh
./prepare.sh k8s
```

This will create the `./dist/` directory with all necessary charts.

### 2. Create Values File

Copy the example values file and customize it with your configuration:

```sh
cp ./charts/example.yaml .secure/values.yaml
```

**Important:** Edit `.secure/values.yaml` and replace all placeholder values (marked with "your-*") with your actual configuration and secrets.

### 3. Configure Default StorageClass

Ensure your cluster has a default StorageClass for persistent volumes:

```sh
# List available storage classes
kubectl get storageclass

# Set a storage class as default (replace <name> with actual storage class name)
kubectl patch storageclass <name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Deployment Order

Deploy the charts in the following order to ensure proper dependencies:

### 1. Bootstrap Chart

The bootstrap chart sets up essential secrets, configuration, and the Let's Encrypt ClusterIssuer for SSL certificates:

```sh
helm install bootstrap ./dist/bootstrap -f .secure/values.yaml --namespace paragon --create-namespace
```

To upgrade:
```sh
helm upgrade bootstrap ./dist/bootstrap -f .secure/values.yaml --namespace paragon
```

**Note**: The bootstrap chart includes a Let's Encrypt ClusterIssuer (`letsencrypt-prod`) that works with cert-manager to automatically provision SSL certificates for all Paragon ingresses. Make sure to configure the Let's Encrypt email address in your `.secure/values.yaml` (this is already included in the example.yaml template).

### 2. Paragon Logging Chart

Deploy logging infrastructure (OpenObserve and Fluent Bit):

```sh
helm install paragon-logging ./dist/paragon-logging -f .secure/values.yaml --namespace paragon
```

To upgrade:
```sh
helm upgrade paragon-logging ./dist/paragon-logging -f .secure/values.yaml --namespace paragon
```

### 3. Paragon Core Chart

Deploy the main Paragon application services:

```sh
helm install paragon-onprem ./dist/paragon-onprem -f .secure/values.yaml --namespace paragon
```

To upgrade:
```sh
helm upgrade paragon-onprem ./dist/paragon-onprem -f .secure/values.yaml --namespace paragon
```

### 4. Paragon Monitoring Chart

Deploy monitoring infrastructure (Prometheus, Grafana, etc.):

```sh
helm install paragon-monitoring ./dist/paragon-monitoring -f .secure/values.yaml --namespace paragon
```

To upgrade:
```sh
helm upgrade paragon-monitoring ./dist/paragon-monitoring -f .secure/values.yaml --namespace paragon
```

## Configuration Reference

### Required Values

The following sections in `.secure/values.yaml` must be configured:

- **dockerCfg**: Docker Hub credentials for pulling Paragon images
- **global.env**: Environment variables and service configuration
- **secrets**: Database credentials, API keys, and other sensitive data
- **fluent-bit.secrets**: OpenObserve credentials for log forwarding
- **openobserve**: Bucket configuration for log storage

### Platform-Specific Notes

- **AWS**: Configure S3 buckets and IAM credentials
- **Azure**: Configure blob storage and service principal credentials  
- **GCP**: Configure GCS buckets and service account credentials
- **On-premises**: Configure external storage and database connections

## Verification

After deployment, verify all services are running:

```sh
# Check pod status
kubectl get pods -n paragon

# Check ingress resources
kubectl get ingress -n paragon

# Check persistent volume claims
kubectl get pvc -n paragon
```

## Security Best Practices

- **Never commit `.secure/values.yaml` to version control**
- Store sensitive values in a secure secrets management system
- Use Kubernetes RBAC to restrict access to the paragon namespace
- Enable encryption at rest for persistent volumes
- Configure network policies to restrict pod-to-pod communication

## Troubleshooting

### Common Issues

1. **PVC stuck in Pending state**: Ensure default StorageClass is configured
2. **Image pull errors**: Verify Docker registry credentials in dockerCfg
3. **Pod startup failures**: Check logs and ensure all required secrets are set
4. **Service connectivity**: Verify DNS resolution and network policies

### Getting Help

- Check pod logs: `kubectl logs <pod-name> -n paragon`
- Describe resources: `kubectl describe <resource-type> <resource-name> -n paragon`
- Review Helm release status: `helm status <release-name> -n paragon`

## Uninstallation

To remove all Paragon components:

```sh
# Remove in reverse order
helm uninstall paragon-monitoring -n paragon
helm uninstall paragon-onprem -n paragon  
helm uninstall paragon-logging -n paragon
helm uninstall bootstrap -n paragon

# Optionally remove the namespace
kubectl delete namespace paragon
```

**Warning**: This will delete all data stored in persistent volumes.
