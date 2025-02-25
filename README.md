<p style="text-align:center"><a href="https://www.useparagon.com/" target="blank"><img src="./assets/paragon-logo-dark.png" width="320" alt="Paragon Logo" /></a></p>

<p style="text-align:center"><b>The embedded integration platform for developers.</b></p>

# Paragon Enterprise

## Overview

This repository is a set of tools to help you run Paragon on your own cloud infrastructure. This Paragon installation comes bundled as a set of [Helm](https://helm.sh/) [charts](./charts/) and [Terraform](https://www.terraform.io/) configs and supports deployment to [Kubernetes](https://kubernetes.io/) running in AWS, GCP or Azure. The charts could also be deployed to other types of Kubernetes clusters but those are not officially supported.

Each of the cloud deployments is split into two Terraform workspaces (`infra` and `paragon`). The `infra` workspace provides the infrastructure that is required to run the Paragon service. This includes provisioning the network, Postgresql databases, Kubernetes cluster, Redis clusters, etc. The `paragon` workspace configures and deploys the Helm resources to Kubernetes cluster created by the `infra` workspace.

See the README files in each of the relevent workspace folders for more details.

## Disclaimers

### Modification strongly discouraged.

We’re constantly deploying new versions of Paragon’s code and infrastructure which often include additional microservices, updates to infrastructure, improved security and more. To ensure new releases of Paragon are compatible with your infrastructure, modifying this repo is strongly discouraged to ensure compatability with future Helm charts and versions of the repo.

Instead of making changes, either:

- send a request to our engineering team to modify the repo (preferred)
- open a pull request with your changes

### ⭐️ We offer managed enterprise solutions. ⭐️

If you want to deploy Paragon to your own cloud but don’t want to manage the infrastructure, we’ll do it for you. Most of our enterprise customers use this solution. Benefits include:

- automatic Paragon and infrastructure upgrades as needed
- continuous monitoring of infrastructure
- cost optimizations on resources

We offer managed enterprise solutions for AWS, Azure and GCP. Please contact **[sales@useparagon.com](mailto:sales@useparagon.com)**, and we’ll get you started.

## Getting Started

### Prerequisites

There are a few prerequisites that are required to be able to fully deploy Paragon:

- a Paragon license key
- a domain name that the Paragon microservices can be reached at (e.g. `paragon.example.com`)
- access to add DNS records for the domain name above
- an SMTP provider such as [SendGrid](https://sendgrid.com/)
- a [Docker account](https://www.docker.com/) that has been given read access to our private repositories
- admin credentials for your Cloud Service Provider for provisioning resources

If you don't already have a license, please contact **[sales@useparagon.com](mailto:sales@useparagon.com)**, and we’ll get you connected.

The local machine that is being used to perform the setup will also require the following software to be installed:

- [Git](https://github.com/git-guides/install-git)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)

### File Prep

Because the Helm charts are cloud provider agnostic they are stored centrally in the [charts](./charts/) folder. Because Terraform supports so many different ways of storing state (local files, remote buckets, Terraform Cloud, etc.) this repo does not declare a `backend` block in the `main.tf` files. We instead provide `main.tf.example` files that will be copied to `main.tf` if not already present. This allows you to customize the `main.tf` files to meet your specific requirements without it being overridden with changes in the repo. To make the management of all of these files easier we provide a bash script that will make all of the necessary file copies. It will also update the Helm chart versions with a hash of the files to ensure that any changes to the chart files will trigger an update. It should be rerun whenever changes have been made to the charts. The [prepare.sh](./prepare.sh) is run by passing in the cloud provider name like:

```bash
./prepare.sh <aws|gcp|azure>
```

## Usage

### Infrastructure Provisioning

Once the Helm charts and Terraform files have been prepared as above then standard Terraform commands can be used within the `<provider>/workspace/infra` directory to provision the necessary resources. See the `infra` README for your cloud provider more details and any required variables.

```
terraform init
terraform validate
terraform plan
terraform apply
```

After the infrastructure has been provisioned the output will be used as input to the `paragon` workspace. This can be accomplished with this command: 

```
terraform output -json > ../paragon/.secure/infra-output.json
```

### Paragon Deployment

Once the infrastructure has been setup then standard Terraform commands can be used within the `<provider>/workspace/paragon` directory to provision the necessary resources. See the `paragon` README for your cloud provider more details and any required variables.

```
terraform init
terraform validate
terraform plan
terraform apply
```

## Direct Helm Deployment

It is highly recommended that all deployments use our Terraform scripts to provision the infrastructure and deploy the Helm charts. Since the infrastructure requirements and configuration may change without warning between releases it could be difficult to reconcile those changes with your installation if not using our Terraform. However if you must deploy the charts to an existing Kubernetes cluster without using Terraform then here are some useful tips.

### Prerequisites

Ensure the following infrastructure components are in place:

- A Kubernetes cluster (AWS EKS, Azure AKS or GCP GKE)
- Postgres database
- Redis cluster
- Domain name for accessing Paragon microservices (e.g., `paragon.example.com`)
- SMTP provider (e.g. SendGrid)
- Docker account with read access to Paragon's private repositories

### Environment Variables

Each chart has its own environment variables defined in the `envKeys` section of the `values.yaml` file. Documenting all possible variables, values and their relevance is beyond the scope of this document. However the defaults for each can be found in the Terraform `variables.tf` for the corresponding provider [aws](./aws/workspaces/paragon/variables.tf), [azure](./azure/workspaces/paragon/variables.tf) or [gcp](./gcp/workspaces/paragon/variables.tf).

While the charts define the `envKeys` on the pod they default to expecting the values to be in a Kubernetes secret using:

```
secretName: "paragon-secrets"
```

#### Required Variables

Because Paragon is highly customizable for various workloads the variables that are required can differ by deployment. Some that are required and can be set to fixed installation specific values are:

- `BRANCH` = "main"
- `HOST_ENV` = \<cloud provider: "AWS_K8", "AZURE_K8" or "GCP_K8">
- `LICENSE` = \<your paragon license key>
- `NODE_ENV` = "production"
- `ORGANIZATION` = \<your company name>
- `PARAGON_DOMAIN` = \<your paragon domain>
- `PLATFORM_ENV` = "enterprise"

#### Variable Conventions

Most of the environment variables that are required are for locating the infrastructure resources defined above or the other microservices.

Each PostgreSQL database requires variables that follow this format:
- `<service>_POSTGRES_DATABASE`
- `<service>_POSTGRES_HOST`
- `<service>_POSTGRES_PORT`
- `<service>_POSTGRES_PASSWORD`
- `<service>_POSTGRES_USERNAME`

Each Redis cluster requires variables that follow this format:
- `<service>_REDIS_URL`
- `<service>_REDIS_CLUSTER_ENABLED`
- `<service>_REDIS_TLS_ENABLED`

Each Paragon microservice requires variables that follow this format:
- `<service>_PORT`
- `<service>_PRIVATE_URL`
- `<service>_PUBLIC_URL`

### Helm Deployment

1. **Add the Paragon Helm repository**:

    ```bash
    helm repo add paragon ./charts
    helm repo update
    ```

2. **Create a `values.yaml` file**:

    Create a `values.yaml` file with the necessary configurations defined above or otherwise required by the charts.

3. **Deploy the Helm charts**:

    ```bash
    helm install paragon paragon/paragon -f values.yaml
    ```
