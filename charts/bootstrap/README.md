# Paragon Helm Charts Deployment Guide

## Overview

This guide covers deploying Paragon using Helm charts directly on Kubernetes. This approach is an alternative to using Terraform workspaces for AWS, Azure, or GCP deployments.

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

The bootstrap chart sets up required dependencies such as: 
- Let's Encrypt ClusterIssuer for SSL certificates
- NGINX Ingress Controller
- essential secrets
- configuration

This chart bootstraps all required dependencies for Paragon, including:

- NGINX Ingress Controller
- Let's Encrypt ClusterIssuer for SSL certificates
- Other required resources

## Prerequisites

### cert-manager

cert-manager must be installed before deploying this chart. Install it using:

```sh
# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.4 \
  --set installCRDs=true
```

## Installation

```sh
# Build the chart with dependencies
helm dependency build ./dist/bootstrap

# Install the bootstrap chart
helm install bootstrap ./dist/bootstrap -f .secure/values.yaml --namespace paragon --create-namespace
```

## Configuration

The following components can be enabled/disabled and configured in `values.yaml`:

### NGINX Ingress Controller

```yaml
ingress-nginx:
  enabled: true
  controller:
    service:
      type: LoadBalancer
```

### Let's Encrypt

```yaml
letsencrypt:
  enabled: true
  email: "your-email@example.com"  # Replace with your email
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

## DNS Configuration

After installing the infrastructure components and deploying Paragon, configure your DNS with the `EXTERNAL-IP` from this command:

1. **Get the Load Balancer endpoint**:
   ```sh
   kubectl get service -n paragon bootstrap-ingress-nginx-controller --output wide
   ```

2. **Set up DNS records** pointing to the load balancer hostname:

   **Option A: Wildcard CNAME (Recommended)**
   ```
   *.<your-domain>                 CNAME   <external-ip-hostname>
   ```
   
   **Note**: If using Cloudflare, ensure DNS-only mode (gray cloud) for proper Let's Encrypt certificate validation.
   
   **Option B: Individual CNAMEs**
   ```
   account.<your-domain>           CNAME   <external-ip-hostname>
   dashboard.<your-domain>         CNAME   <external-ip-hostname>
   cerberus.<your-domain>          CNAME   <external-ip-hostname>
   # ... etc for all services
   ```

   **For the naked/apex domain** (optional):
   ```
   # AWS Route 53 (recommended for AWS)
   <your-domain>                   ALIAS   <external-ip-hostname>
   
   # Cloudflare - DNS-only mode (not proxied!)
   <your-domain>                   CNAME   <external-ip-hostname>  (DNS-only, gray cloud)
   
   # Traditional DNS providers - use A record with IP
   <your-domain>                   A       <external-ip>
   ```

   **⚠️ Important for Cloudflare users**: If using Cloudflare, make sure to use **DNS-only mode** (gray cloud icon) rather than proxied mode (orange cloud). Proxied mode will break Let's Encrypt certificate validation since Cloudflare terminates TLS at their edge instead of your ingress controller.

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

If you see `cm-acme-http-solver` entries in the `ingress` list then the certificates are still being generated. Attempts to connect to those services may result in an unsecure certificate error. This process may take several minutes for a new domain. Here are some additional commands to get more details about the process:

```sh
kubectl get certificate -n paragon
kubectl get order -n paragon
kubectl get challenge -n paragon
kubectl logs -l app.kubernetes.io/name=cert-manager -n cert-manager
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
