# Paragon Helm Charts Deployment Guide

## Overview

This guide covers deploying Paragon using Helm charts directly on Kubernetes. This approach is an alternative to using Terraform workspaces for AWS, Azure, or GCP deployments.

## Prerequisites

- Kubernetes cluster with kubectl access
- Helm 3.x installed
- A default StorageClass configured in your cluster
- Docker registry credentials for pulling Paragon images

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

The bootstrap chart sets up essential secrets and configuration:

```sh
helm install bootstrap ./dist/bootstrap -f .secure/values.yaml --namespace paragon --create-namespace
```

To upgrade:
```sh
helm upgrade bootstrap ./dist/bootstrap -f .secure/values.yaml --namespace paragon
```

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
