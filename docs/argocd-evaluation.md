# ArgoCD Deployment Evaluation

## Executive Summary

This document evaluates replacing the Terraform Helm provider (used in each cloud provider's `paragon` workspace) with ArgoCD for managing Helm chart deployments across 40 customer clusters (primarily AWS). The goal is to eliminate the need for Terraform to access the Kubernetes API, enable daily GitOps-based upgrades (up from monthly), provide rollback and drift detection, and stay on Spacelift Starter.

**Recommendation:** Adopt ArgoCD with External Secrets Operator (ESO). The entire `paragon` workspace can be eliminated by moving cloud-API-only resources (ALB, DNS, uptime, monitors, Hoop API connections) into the `infra` workspace and moving all Helm releases / K8s resources to ArgoCD. The `infra` workspace's Helm/Kubernetes provider dependency (cluster-autoscaler module) can also be removed by moving the autoscaler to ArgoCD management (and optionally migrating to Karpenter later). ArgoCD itself can be bootstrapped without a public K8s API on all three clouds — via EKS addon on AWS, `az aks command invoke` on Azure, and GKE Connect Gateway on GCP.

This results in a single Terraform workspace (`infra`) per customer that only calls cloud provider APIs — no K8s API access, no private runners, Spacelift Starter is sufficient. The Karpenter migration is recommended but should be decoupled from the ArgoCD adoption to reduce risk across the 40 clusters.

---

## Context from Follow-up Questions

| Question | Answer | Impact |
|----------|--------|--------|
| Active customer clusters | **40** | ApplicationSet is worthwhile; migration must be phased |
| Secret management | **None today; prefer cloud-native (AWS Secrets Manager)** | External Secrets Operator is the right path |
| `managed_sync_enabled` | **Subset of customers** | Can defer managed-sync migration; `helm-config` complexity affects fewer clusters |
| Dominant cloud provider | **AWS** | Prioritize AWS implementation; Azure/GCP follow |
| Upgrade frequency | **Monthly → target daily** | GitOps automation is high priority |
| Customer config organization | **Per-customer Spacelift stacks in `enterprise-deployments` repo** | Config stays in that repo; ArgoCD reads from it |
| Managed enterprise uses same approach? | **Yes** | ArgoCD benefits managed offering equally |
| Compliance requirements | **Auditable, minimal centralized connections** | Per-cluster ArgoCD is the right model |
| Hoop deployed everywhere? | **Yes** | Must handle Hoop in every migration |
| Slack notifications | **Yes** | ArgoCD Notifications controller with Slack integration |
| `update-charts.yaml` trigger | **Automatic; want it to also set chart versions, remove `prepare.sh`, host charts externally** | Aligns perfectly with ArgoCD + versioned Helm chart registry |
| Terraform state backend | **S3** | State migration via `terraform state rm` is straightforward |

---

## Current Architecture Analysis

### How it works today

```
┌──────────────────────────────────────────────────────────────────────┐
│ Spacelift (Starter) + enterprise-deployments repo                    │
│                                                                      │
│  infra workspace ──► cloud APIs ──► VPC, EKS, Postgres, Redis, S3   │
│       │              + K8s API  ──► cluster-autoscaler (helm_release)│
│       │                                                              │
│       ▼ outputs (infra-output.json)                                  │
│                                                                      │
│  paragon workspace ──► K8s API ──► helm_release resources            │
│       │                    ▲        (paragon-onprem, logging,        │
│       │                    │         monitoring, managed-sync,        │
│       │                    │         ingress, metrics-server, hoop)   │
│       │                    │                                         │
│       │              Requires direct network access                   │
│       │              to K8s API (public endpoint or VPC runner)       │
│       │                                                              │
│       └──► ALB/DNS, uptime monitors, Grafana IAM, Hoop connections   │
└──────────────────────────────────────────────────────────────────────┘
```

### Pain points identified

| Problem | Details |
|---------|---------|
| **Dual config locations** | Environment variables defined in `.secure/values.yaml`, merged/augmented in `variables.tf` locals (~200 env vars from `infra_vars` + `helm_vars`), and cloud-specific values injected via `set`/`set_sensitive` in `helm.tf`. A single config change may touch 2-3 files. |
| **K8s API access from Spacelift** | Both `infra` (cluster-autoscaler) and `paragon` (all Helm releases) require K8s API access. The EKS endpoint must be public or the runner must be in-VPC. |
| **VPC runner cost** | Private Spacelift workers require enterprise plan. Current workaround is public K8s API — a security concern. |
| **No GitOps / rollback** | Deployments are imperative (`terraform apply`). Rolling back means reverting state + re-applying. No drift detection. |
| **Upgrade friction at scale** | Monthly upgrades across 40 clusters require running `prepare.sh`, updating `VERSION`, then `terraform apply` per customer on both workspaces. Daily upgrades are impractical with this approach. |
| **`prepare.sh` complexity** | Chart preparation involves extracting from git tags, computing SHA hashes, rsync-ing charts into provider directories, and sed-replacing version placeholders. This could be replaced by a proper Helm chart registry with versioned releases. |

---

## Proposed Architecture with ArgoCD

```
┌──────────────────────────────────────────────────────────────────────┐
│ Spacelift (Starter) — public cloud APIs only                         │
│                                                                      │
│  infra workspace (single workspace) ──► cloud APIs only:             │
│    • VPC, EKS, Postgres, Redis, S3                                   │
│    • Karpenter (EKS addon, replaces cluster-autoscaler helm_release) │
│    • ArgoCD bootstrap (EKS addon or one-time helm_release)           │
│    • External Secrets Operator bootstrap                             │
│    • ACM certificates, DNS records (moved from paragon)              │
│    • Uptime monitors (moved from paragon)                            │
│    • Grafana IAM (moved from paragon)                                │
│    • Hoop API connections (moved from paragon)                       │
│    • AWS Secrets Manager entries (infra outputs → secrets store)      │
│                                                                      │
│  paragon workspace ──► ELIMINATED                                    │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ ArgoCD (runs inside each customer's EKS cluster)                     │
│                                                                      │
│  Watches versioned Helm chart repo + customer config repo:           │
│    • paragon-onprem (all microservices)                               │
│    • paragon-logging (fluent-bit + openobserve)                      │
│    • paragon-monitoring (grafana, prometheus, exporters)              │
│    • managed-sync (when enabled)                                     │
│    • ingress controller (ALB controller / NGINX / GKE)               │
│    • metrics-server, node-termination-handler                        │
│    • hoop agent                                                      │
│    • External Secrets Operator (self-managing)                       │
│                                                                      │
│  Secrets flow:                                                       │
│    AWS Secrets Manager ──► ESO ──► K8s Secrets ──► Pods              │
│                                                                      │
│  Features:                                                           │
│    • Automatic sync on Git push (daily releases)                     │
│    • Drift detection + self-healing                                  │
│    • One-click rollback                                              │
│    • Slack notifications on sync events                              │
│    • App-of-Apps pattern for ordered deployment                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Answering the Key Questions

### 1. Can we eliminate the Terraform Helm provider entirely?

**Yes — from both workspaces.**

**`paragon` workspace:** Eliminated entirely. All `helm_release` and `kubernetes_*` resources move to ArgoCD. Cloud-API-only resources move to the `infra` workspace.

**`infra` workspace:** The only Helm provider usage is the `lablabs/eks-cluster-autoscaler` module which installs cluster-autoscaler via `helm_release`. This can be replaced by:

- **Karpenter as an EKS addon** (`aws_eks_addon` resource, same pattern as the existing EBS CSI driver, CoreDNS, kube-proxy, and vpc-cni addons in `cluster.tf`). Karpenter is the AWS-recommended successor to cluster-autoscaler and is available as a first-party EKS addon.
- **Or:** Move cluster-autoscaler to ArgoCD along with the other charts (ArgoCD is bootstrapped first, then manages the autoscaler).

Either approach eliminates the Helm and Kubernetes providers from the `infra` workspace entirely. The EBS CSI driver is already installed via `aws_eks_addon` — no Helm involved.

**Result:** Zero `helm_release` resources remain in Terraform. The Helm and Kubernetes providers can be removed from `required_providers` across all workspaces.

### 2. Can we remove the need for private VPC Terraform execution?

**Yes — completely.** With the changes above:

- `infra` workspace uses only: `aws` provider (EC2, EKS, RDS, ElastiCache, S3, IAM, KMS, Route53, ACM, Secrets Manager), `random`, `tls`, `betteruptime`, `hoop`, `cloudflare` — all public APIs
- `paragon` workspace is eliminated
- ArgoCD runs inside the cluster — no external runner

Spacelift Starter with public runners is sufficient for all 40 clusters.

### 3. Does GitOps provide reliable, automated upgrades?

**Yes — and this is where the biggest operational win comes from at your scale.**

**Current upgrade workflow (per customer):**
1. Run `prepare.sh -p aws -t <VERSION>` (extracts from git tag, hashes charts, rsync, sed-replaces versions)
2. Update `VERSION` in `.secure/values.yaml`
3. `terraform apply` in infra workspace
4. `terraform apply` in paragon workspace
5. Repeat 40 times for monthly releases

**Proposed upgrade workflow:**
1. CI publishes new chart versions to a Helm chart registry (OCI-based, e.g. ECR, GitHub Container Registry, or S3-hosted)
2. `update-charts.yaml` GitHub Action updates chart version references in the `enterprise-deployments` repo (or this repo)
3. ArgoCD detects the change and syncs automatically across all 40 clusters
4. Slack notification confirms success/failure per cluster

**Going from monthly to daily:** The current workflow is impractical for daily releases across 40 clusters. With ArgoCD, a single Git commit can trigger deployments to all clusters simultaneously, with per-cluster health checks and automatic rollback on failure.

**Removing `prepare.sh`:** Your instinct to have the GitHub Action set chart versions directly and host charts externally is exactly right. With a proper Helm chart registry:
- Charts are published with semantic versions as part of CI/CD
- ArgoCD `Application` manifests reference charts by `repository` + `chart` + `targetRevision` (version constraint)
- No more rsync-ing charts into provider directories, no SHA hash-based synthetic versions, no `__PARAGON_VERSION__` sed replacements
- `prepare.sh` becomes unnecessary

### 4. Does this improve rollback and drift handling?

**Significantly — and this is critical for daily releases.**

**Rollback:**
- **Current:** Revert Terraform state + re-apply. At 40 clusters, a bad monthly release is a multi-day incident.
- **With ArgoCD:** `argocd app rollback <app> <revision>` per cluster, or automated via sync policy. ArgoCD maintains history of every synced Git revision. A bad daily release can be rolled back in minutes.

**Drift detection:**
- **Current:** None. If someone `kubectl edit`s a resource, it goes undetected until the next `terraform plan`.
- **With ArgoCD:** Continuous comparison of live state vs. Git (every 3 min default). Drift is visible in the ArgoCD UI and can be auto-corrected with `selfHeal: true`. Slack notifications on drift events.

### 5. Does this allow us to remain on Spacelift Starter?

**Yes.** All Terraform operations become cloud-API-only. No K8s API access from Spacelift. No private workers needed. The `enterprise-deployments` repo Spacelift stacks continue to work — they just run a simpler, single `infra` workspace per customer.

### 6. Does GitOps simplify multi-customer application management?

**Yes — especially given the `enterprise-deployments` repo structure.**

Since customer configs already live as Spacelift stacks in `enterprise-deployments`, the migration path is:

1. **Infra workspace** continues to be managed by Spacelift stacks in `enterprise-deployments` (provisions cloud resources + bootstraps ArgoCD)
2. **`infra` workspace outputs** are written to AWS Secrets Manager (instead of `infra-output.json`)
3. **ArgoCD** in each cluster reads Application manifests from this repo (chart definitions) and customer-specific values from the `enterprise-deployments` repo (via ArgoCD multi-source or a config branch)
4. **External Secrets Operator** pulls secrets from AWS Secrets Manager into K8s Secrets

**Upgrade across 40 clusters:** Update the chart version in a single place → ArgoCD syncs all clusters. No per-customer Terraform apply.

**Adding a new customer:** Create Spacelift stack in `enterprise-deployments` (infra only), run `terraform apply` once (provisions infra + bootstraps ArgoCD), ArgoCD auto-deploys all charts.

### 7. Should each cluster have its own ArgoCD instance?

**Yes — this is the clear choice given your requirements:**

- **Auditable with minimal centralized connections** — each ArgoCD is isolated, operates on in-cluster ServiceAccount only, audit trail per cluster
- **40 customer clusters in separate cloud accounts** — no cross-VPC connectivity needed
- **Hoop deployed everywhere** — Hoop agent can provide audited access to each ArgoCD instance when needed
- **No compliance concerns with centralization** — each customer's ArgoCD touches only their cluster

---

## Answering Additional Questions

### Q1: Can the EBS CSI driver and ArgoCD be deployed without `helm_release`?

**Yes — both can be deployed without the Terraform Helm provider.**

**EBS CSI driver:** Already deployed without `helm_release`. It uses `aws_eks_addon` in `aws/workspaces/infra/cluster/cluster.tf`:

```hcl
resource "aws_eks_addon" "addons" {
  for_each = local.cluster_addons  # includes "aws-ebs-csi-driver"
  addon_name   = each.key
  addon_version = try(each.value.version, null)
  cluster_name = module.eks.cluster_name
  service_account_role_arn = each.key == "aws-ebs-csi-driver"
    ? module.aws_ebs_csi_driver_iam_role.iam_role_arn : null
  # ...
}
```

This is a pure AWS API call — no Kubernetes or Helm provider needed. The `aws_eks_addon` resource talks to the EKS control plane API (an AWS API), not the Kubernetes API directly.

**ArgoCD:** Multiple options, none requiring the Terraform Helm provider:

| Option | How it works | Terraform provider needed |
|--------|-------------|--------------------------|
| **EKS Blueprints Addon** | Use the `aws_eks_addon` resource with the ArgoCD add-on from the EKS marketplace | `aws` only |
| **EKS Blueprints ArgoCD module** | Terraform module `aws-ia/eks-blueprints-addons/aws` supports ArgoCD as a managed add-on — it uses `helm_release` internally, but only during initial bootstrap | `helm` (one-time bootstrap only) |
| **`kubectl apply` via `null_resource`** | Apply ArgoCD's install manifests via a `local-exec` provisioner that runs `kubectl apply` | None (just `null_resource`) |
| **Bootstrapped via user-data / cloud-init** | EKS node bootstrap script or a Lambda function applies ArgoCD manifests post-cluster-creation | None |
| **ArgoCD Autopilot** | CLI tool that bootstraps ArgoCD and configures it to manage itself from a Git repo | None (one-time CLI run) |

**Recommended approach:** Use `aws_eks_addon` if the ArgoCD EKS marketplace add-on meets your version/config needs. Otherwise, accept a minimal `helm_release` for the one-time ArgoCD bootstrap — this is the only Helm resource in the entire codebase, runs once per cluster creation, and ArgoCD self-manages after that. The K8s API endpoint can be temporarily public during initial provisioning and then restricted.

**Cluster-autoscaler (the other Helm usage in `infra`):** The `lablabs/eks-cluster-autoscaler` module currently uses `helm_release`. Options:

1. **Replace with Karpenter EKS addon:** `aws_eks_addon` with `eks-pod-identity-agent` + Karpenter. Pure AWS API, no Helm provider. Karpenter is AWS's recommended autoscaler.
2. **Move cluster-autoscaler to ArgoCD:** After ArgoCD bootstraps, it manages the cluster-autoscaler Helm chart. Removes it from Terraform.
3. **Replace with EKS Auto Mode:** If on EKS 1.29+, EKS Auto Mode provides managed Karpenter — no addon or Helm chart needed at all. Just a cluster configuration flag.

Any of these eliminates the last `helm_release` from the `infra` workspace, allowing you to remove the Helm and Kubernetes providers entirely.

### Q3: Can ArgoCD be deployed to Azure and GCP clusters without a public K8s API?

**Yes — and Azure/GCP are actually easier than AWS in this regard.**

The key insight is that ArgoCD runs *inside* the cluster it manages. It never needs external K8s API access — it uses the in-cluster ServiceAccount. The question is really about how to *bootstrap* ArgoCD onto a private cluster, since Terraform (running outside the cluster) can't reach the K8s API.

#### Azure (AKS)

The Azure `infra` workspace already has **no Kubernetes or Helm providers** — `providers.tf` only declares `azurerm` and `azuread`. AKS is provisioned entirely via `azurerm_kubernetes_cluster` and `azurerm_kubernetes_cluster_node_pool` resources (pure Azure ARM API calls). There is nothing to remove.

**Bootstrap options for ArgoCD on private AKS:**

| Option | How it works | Needs public API? |
|--------|-------------|-------------------|
| **AKS GitOps extension (Flux-based)** | `azurerm_kubernetes_cluster_extension` with `extension_type = "Microsoft.Flux"` — a native AKS feature that installs GitOps from the Azure API. While this installs Flux rather than ArgoCD, it can be used to bootstrap ArgoCD as the first Flux `HelmRelease`. | **No** — pure Azure ARM API |
| **AKS `command invoke`** | `azurerm_kubernetes_command` (or `az aks command invoke` via `null_resource`) runs `kubectl`/`helm` commands on the cluster through the Azure API, tunneled via the managed control plane. Works even with fully private endpoints. | **No** — tunneled through Azure API |
| **Azure Deployment Script** | `azurerm_resource_group_template_deployment` with a deployment script that runs inside the VNet and applies ArgoCD manifests. | **No** — runs in-VNet |
| **One-time `helm_release`** | Accept a single `helm_release` for bootstrap, same as AWS. Run `terraform apply` once with public endpoint, then disable it. | **Temporarily** — one-time only |

**Recommended for Azure:** Use `az aks command invoke` via a `null_resource` / `local-exec` provisioner. This is the simplest option — it sends `kubectl apply` commands through the Azure API without exposing the K8s endpoint. Example:

```hcl
resource "null_resource" "argocd_bootstrap" {
  provisioner "local-exec" {
    command = <<-EOT
      az aks command invoke \
        --resource-group ${azurerm_kubernetes_cluster.cluster.resource_group_name} \
        --name ${azurerm_kubernetes_cluster.cluster.name} \
        --command "kubectl create namespace argocd && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    EOT
  }
  depends_on = [azurerm_kubernetes_cluster_node_pool.pool]
}
```

After this one-time bootstrap, ArgoCD manages itself (self-managing Application) and all other charts. No ongoing external K8s API access needed.

#### GCP (GKE)

The GCP `infra` workspace also has **no Kubernetes or Helm providers** — `providers.tf` only declares `google` and `google-beta`. The GKE cluster is provisioned via the `terraform-google-modules/kubernetes-engine/google//modules/private-cluster` module, which already supports a `disable_public_endpoint` variable (currently exposed as `var.disable_public_endpoint` in the cluster config).

**Bootstrap options for ArgoCD on private GKE:**

| Option | How it works | Needs public API? |
|--------|-------------|-------------------|
| **GKE Config Management** | `google_gke_hub_feature` + `google_gke_hub_feature_membership` with Config Sync — a native GKE feature that enables GitOps via the GCP API. Can bootstrap ArgoCD as its first sync target. | **No** — pure GCP API |
| **Connect Gateway** | GKE Connect Gateway (`gcloud container fleet memberships generate-gateway-rbac`) allows `kubectl` access through the GCP API for Fleet-enrolled clusters. Use a `null_resource` with `gcloud` commands to apply ArgoCD manifests via the gateway. | **No** — tunneled through GCP API |
| **Bastion / IAP tunnel** | The GCP infra workspace already provisions a bastion. A `null_resource` can SSH through IAP to the bastion and run `kubectl apply` to install ArgoCD. | **No** — tunneled through IAP |
| **Master authorized networks** | The GKE module already supports `master_authorized_networks`. Allow the Spacelift runner's IP temporarily, apply ArgoCD, then remove. | **Temporarily** — restricted window |
| **One-time `helm_release`** | Same as AWS/Azure — accept a one-time Helm provider usage during initial provisioning. | **Temporarily** |

**Recommended for GCP:** Use GKE Connect Gateway via `null_resource`. Fleet enrollment is a single `google_gke_hub_membership` resource (GCP API), and `kubectl` commands then go through the GCP API without exposing the K8s endpoint. Alternatively, if the bastion is already provisioned, tunnel through it.

#### Summary: ArgoCD bootstrap without public K8s API

| Cloud | Current K8s/Helm provider in `infra`? | ArgoCD bootstrap method | Public K8s API needed? |
|-------|---------------------------------------|------------------------|----------------------|
| **AWS** | Yes (cluster-autoscaler only) | `aws_eks_addon` or one-time `helm_release` | EKS addon: **No**. `helm_release`: temporarily |
| **Azure** | **No** | `az aks command invoke` via `null_resource` | **No** |
| **GCP** | **No** | GKE Connect Gateway or bastion tunnel via `null_resource` | **No** |

Azure and GCP are actually in a better position than AWS — their `infra` workspaces already have zero Helm/K8s provider usage, and both clouds offer API-tunneled `kubectl` access for the one-time ArgoCD bootstrap.

### Q4: Are there other downsides or benefits to switching to the Karpenter addon for AWS?

The current setup uses `lablabs/eks-cluster-autoscaler` (Helm-based Cluster Autoscaler) in the `infra` workspace and `qvest-digital/aws-node-termination-handler` (Helm-based NTH) in the `paragon` workspace. Switching to Karpenter replaces both.

#### Benefits

| Benefit | Details |
|---------|---------|
| **Eliminates Helm/K8s providers from `infra`** | The cluster-autoscaler module is the only reason the AWS `infra` workspace needs the Helm and Kubernetes providers. Karpenter as an EKS addon (`aws_eks_addon`) is a pure AWS API call — same pattern as the existing EBS CSI, CoreDNS, kube-proxy, and vpc-cni addons. |
| **Eliminates aws-node-termination-handler** | Karpenter natively handles spot interruptions, instance rebalancing, and EC2 health events. The separate `aws_node_termination_handler` module (currently in the `paragon/helm/` workspace) is no longer needed. That's one less Helm chart to manage. |
| **Faster scaling** | Cluster Autoscaler works at the Auto Scaling Group level — it adjusts `desired_count` and waits for the ASG to provision. Karpenter provisions EC2 instances directly, bypassing the ASG. Typical improvement: 60-90 seconds vs. 3-5 minutes for new nodes. |
| **Better instance selection** | Cluster Autoscaler is limited to the instance types defined in the managed node group. The current config uses `eks_ondemand_node_instance_type` and `eks_spot_node_instance_type` (single-type lists). Karpenter can dynamically select from a wide range of instance types based on pod requirements and availability, improving cost and availability. |
| **Simplified node group management** | Currently, Terraform manages explicit node groups with `module.eks_managed_node_group` (on-demand and spot pools with separate instance types, min/max counts). Karpenter replaces this with `NodePool` and `EC2NodeClass` CRDs that declaratively express constraints. Node groups become optional or can be minimal (one small on-demand group for system components). |
| **Better bin-packing** | Karpenter consolidates underutilized nodes by moving pods and terminating empty nodes. Cluster Autoscaler only scales down nodes that become fully empty (or where all pods are movable). This can reduce costs for workloads with variable load — relevant if the 40 clusters have uneven utilization. |
| **ArgoCD-managed after bootstrap** | Since Karpenter's `NodePool`/`EC2NodeClass` CRDs are Kubernetes manifests, ArgoCD can manage them. Changes to node configuration become GitOps-driven and auditable — aligning with the overall goal. |
| **AWS-recommended path** | AWS has officially designated Karpenter as the recommended autoscaler for EKS. The Cluster Autoscaler continues to work but receives less investment. |

#### Downsides / Risks

| Risk | Details | Mitigation |
|------|---------|------------|
| **Migration complexity for 40 clusters** | Switching autoscalers requires careful node draining. Karpenter and Cluster Autoscaler can't run simultaneously on the same node groups — Karpenter needs to manage its own nodes. | Run Karpenter alongside existing managed node groups during transition. Karpenter ignores nodes it didn't create. Gradually taint/drain old node groups as Karpenter provisions replacements. |
| **`NodePool`/`EC2NodeClass` CRD management** | Today, node configuration is Terraform variables (`eks_ondemand_node_instance_type`, `eks_spot_instance_percent`, `eks_min/max_node_count`). With Karpenter, these become K8s CRDs. The configuration format changes. | ArgoCD manages the CRDs. Customer-specific node config goes into the same values/config system as the rest of the application. Actually a benefit — node config is now GitOps-managed alongside everything else. |
| **Managed node groups still needed for system components** | Karpenter itself, CoreDNS, and kube-proxy need nodes to run on. You can't remove all managed node groups — you need at least a small on-demand group for the control plane components. | Keep the existing `default_node_pool` (or a minimal managed node group). The current AWS config already has separate on-demand/spot groups; the on-demand group can be minimized to a small always-on pool. |
| **Spot handling behavioral changes** | Cluster Autoscaler + NTH uses ASG-based spot pools with explicit instance types. Karpenter uses `capacity-spread` and `on-demand` fallback. The spot behavior is different — instance diversity is broader, which is generally better but changes the cost/availability profile. | Configure Karpenter's `NodePool` with explicit `instanceTypes` constraints if you need to restrict instance families. The current `eks_spot_node_instance_type` list can be directly mapped. |
| **IAM changes** | Karpenter needs its own IAM role with EC2 permissions (launch instances, create/tag ENIs, manage security groups). Different from the Cluster Autoscaler's ASG-only permissions. | The `aws_eks_addon` for Karpenter can use pod identity or IRSA. The EKS Blueprints addon module handles IAM automatically. Straightforward Terraform IAM resources, same pattern as the existing `aws_ebs_csi_driver_iam_role`. |
| **Learning curve** | Operations team needs to understand Karpenter's `NodePool`/`EC2NodeClass` model instead of ASG-based autoscaling. Debugging is different (Karpenter logs vs. ASG events). | Karpenter has excellent documentation and observability. The Prometheus metrics are richer than Cluster Autoscaler's. The ArgoCD UI + Grafana dashboards provide visibility into node provisioning. |
| **Version compatibility** | Karpenter versions are tied to specific EKS versions. Must validate compatibility with the current `k8s_version = "1.31"` in `cluster/variables.tf`. | Karpenter v1.x supports EKS 1.25+. Version 1.31 is well within support range. Pin the addon version, same as other EKS addons. |
| **Terraform variable changes** | The current `eks_spot_instance_percent`, `eks_min/max_node_count`, `eks_ondemand/spot_node_instance_type` variables in `infra/cluster/variables.tf` no longer directly apply. The 40 customers' `vars.auto.tfvars` files reference these. | During migration, keep the variables but use them to generate Karpenter `NodePool` CRDs (via a ConfigMap or ArgoCD values). Or migrate customer configs in the `enterprise-deployments` repo to the new Karpenter-native format. |

#### Recommendation

**Switch to Karpenter, but decouple it from the ArgoCD migration.**

- **Phase 0 (ArgoCD migration):** Keep Cluster Autoscaler as-is but move it from `infra` Terraform to ArgoCD management (ArgoCD installs the existing cluster-autoscaler Helm chart). This eliminates the Helm provider from `infra` without changing autoscaler behavior. Also move `aws-node-termination-handler` to ArgoCD.
- **Phase N (later):** Migrate from Cluster Autoscaler to Karpenter. This is a separate project that can be done per-cluster at your own pace. ArgoCD manages the Karpenter `NodePool` CRDs. Once migrated, remove the cluster-autoscaler and NTH ArgoCD Applications.

This avoids conflating two significant changes (GitOps migration + autoscaler migration) in one risky step across 40 clusters. However, if you want to minimize the number of migrations, doing both together on the pilot cluster (Phase 1) is reasonable — just don't batch-roll both changes to all 40 at once.

### Q2: Can paragon workspace resources that won't be replaced by ArgoCD move to infra?

**Yes — and this is the recommended approach.** It eliminates the `paragon` workspace entirely, leaving a single `infra` Terraform workspace per customer.

Here's what each submodule needs and whether it can move:

#### AWS `paragon` → `infra` migration

| Module | Current providers | Depends on K8s? | Can move to infra? | Dependencies to resolve |
|--------|-------------------|------------------|--------------------|-----------------------|
| **`alb/`** | `aws`, `cloudflare` | No, but has `depends_on` on `release_ingress` and `release_paragon_on_prem` | **Yes** | Remove Helm release dependencies. ALB is created by the ingress controller (deployed by ArgoCD). DNS records can use a data source to find the ALB after ArgoCD deploys ingress, or use a known/predictable LB name. |
| **`uptime/`** | `betteruptime` | No | **Yes** | Needs `microservices` map with `public_url` values. These are deterministic from `organization` + `domain` — can be computed in `infra` locals. |
| **`monitors/`** | `aws`, `random` | No | **Yes** | Needs Grafana/PGAdmin credentials. These can be generated in `infra` and stored in Secrets Manager. |
| **`helm-config/`** | `random`, `tls` | No | **Yes** | Needs `base_helm_values`, `infra_values`, `microservices`, `domain`. The infra workspace already has `infra_values` (it produces them). `base_helm_values` and `microservices` can be computed from the same inputs. Generated secrets (random passwords, TLS keys) should be written to AWS Secrets Manager for ESO to sync. |
| **`hoop/` (API part)** | `hoop` | **Partial** — `hoop_connection` depends on `data.kubernetes_secret.hoop_cluster_admin_token` | **Mostly yes, with redesign** | See detailed analysis below. |

#### Hoop module: detailed migration analysis

The Hoop module has two distinct parts:

**Part 1: In-cluster resources (moves to ArgoCD)**
- `helm_release.hoopagent` — Hoop agent chart
- `kubernetes_service_account.hoop_cluster_admin` — SA for cluster access
- `kubernetes_cluster_role_binding` — RBAC
- `kubernetes_secret` — SA token

**Part 2: Hoop API resources (moves to infra — with redesign)**
- `hoop_connection.all_connections` — API calls to Hoop SaaS
- `hoop_connection.postgres_connections` — API calls to Hoop SaaS
- `hoop_plugin_connection.*` — API calls to Hoop SaaS
- `hoop_plugin_config.*` — Slack integration config

The problem: `hoop_connection` resources currently `depends_on` a `data.kubernetes_secret` (the SA token). This creates a K8s API dependency. To move Hoop API resources to the `infra` workspace:

**Option A (recommended):** Remove the `depends_on` on `data.kubernetes_secret.hoop_cluster_admin_token`. The Hoop connections don't actually *use* the token value — the dependency is only for ordering (ensure the SA exists before creating connections). In the ArgoCD model, the SA is created by ArgoCD when deploying the Hoop agent chart. The Hoop API connections can be created independently — they reference the agent by `agent_id`, not by the SA token. The connections will work once the agent comes online.

**Option B:** Use a two-phase approach — `infra` creates connections, ArgoCD deploys the agent. The agent registers with Hoop using its `hoop_key`, and connections are already configured. This is the standard Hoop workflow.

#### Azure and GCP: same pattern

Azure and GCP `paragon` workspaces have the same submodule structure minus `alb/` (they have `dns/` instead). The `dns/` module uses Cloudflare and depends on the load balancer IP/hostname from the Helm ingress — same dependency resolution as AWS `alb/`.

#### Result: single `infra` workspace

After migration:

```
{provider}/workspaces/infra/
├── bastion/          (existing)
├── cluster/          (existing — minus cluster-autoscaler helm)
├── kafka/            (existing)
├── network/          (existing)
├── postgres/         (existing)
├── redis/            (existing)
├── storage/          (existing)
├── alb/              (moved from paragon — AWS only)
├── dns/              (moved from paragon — Azure/GCP only)
├── uptime/           (moved from paragon)
├── monitors/         (moved from paragon)
├── hoop-connections/ (moved from paragon/hoop, API-only)
├── secrets/          (NEW — writes computed config to Secrets Manager)
├── argocd/           (NEW — one-time bootstrap)
├── data.tf
├── main.tf
├── modules.tf
├── outputs.tf
├── providers.tf
└── variables.tf
```

The `paragon` workspace directory is removed. The `enterprise-deployments` repo Spacelift stacks each point to a single workspace.

---

## Implementation Approach (Revised)

### Architecture decisions

Based on the follow-up answers, the recommended architecture is:

1. **Helm chart registry:** Publish charts to an OCI registry (ECR or GHCR) with semantic versioning. The `update-charts.yaml` GitHub Action publishes new versions. `prepare.sh` is retired.
2. **External Secrets Operator + AWS Secrets Manager:** Infra workspace writes computed config (merged `infra_vars` + `helm_vars` + generated credentials) to Secrets Manager. ESO syncs to K8s Secrets. No secrets in Git.
3. **ArgoCD multi-source Applications:** Chart source from the registry, values from the `enterprise-deployments` repo (customer-specific non-secret config).
4. **App-of-Apps with sync waves:** Ordered deployment (ingress → secrets → core app → logging → monitoring).
5. **ArgoCD Notifications:** Slack integration for sync events across all 40 clusters.
6. **Per-cluster ArgoCD:** Each of the 40 clusters runs its own ArgoCD instance.

### Secrets and config flow (detailed)

This is the most significant architectural change. Currently, `variables.tf` computes ~200 env vars by merging:
- `infra_vars` (from `infra-output.json`) — database endpoints, Redis hosts, S3 buckets, IAM credentials
- `helm_vars` (from `.secure/values.yaml`) — application config, license, feature flags
- Computed locals — service URLs, ports, private URLs, storage config
- `helm-config/secrets.tf` — managed sync credentials (random passwords, TLS keys, Kafka/Redis/Postgres config)

**Proposed replacement:**

```
┌─────────────────────────────────────────────────────────────┐
│ Terraform infra workspace                                    │
│                                                              │
│  1. Provisions infra (existing)                              │
│  2. Computes merged config (same logic as current            │
│     variables.tf, but outputs to Secrets Manager             │
│     instead of helm_values)                                  │
│  3. Writes to AWS Secrets Manager:                           │
│     • paragon/<org>/env → all env vars (merged)              │
│     • paragon/<org>/managed-sync → managed sync secrets      │
│     • paragon/<org>/docker-cfg → docker credentials          │
│     • paragon/<org>/openobserve → logging credentials        │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│ External Secrets Operator (in-cluster, deployed by ArgoCD)   │
│                                                              │
│  ExternalSecret CRDs reference Secrets Manager paths:        │
│  • paragon-secrets ← paragon/<org>/env                       │
│  • docker-cfg ← paragon/<org>/docker-cfg                     │
│  • managed-sync-secrets ← paragon/<org>/managed-sync         │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│ ArgoCD Applications (Helm charts from registry)              │
│                                                              │
│  Charts reference K8s Secrets by name (same as today):       │
│  • secretName: "paragon-secrets"                             │
│  • imagePullSecrets: "docker-cfg"                            │
│                                                              │
│  Non-secret values (ports, domains, feature flags)           │
│  come from values files in enterprise-deployments repo       │
└─────────────────────────────────────────────────────────────┘
```

This preserves the existing `variables.tf` merge logic — it just outputs to Secrets Manager instead of `helm_values`. The charts don't need to change at all since they already reference `paragon-secrets` by name.

### Chart hosting and versioning

**Current:** Charts live in this repo under `charts/`, are copied/prepared by `prepare.sh`, and versioned with SHA hashes of file contents.

**Proposed:**
1. Charts move to their own repo (or stay here, but are published as artifacts)
2. CI pipeline on chart changes: `helm package` → `helm push` to OCI registry
3. Versions follow semver (e.g., `paragon-onprem:2026.04.01`)
4. ArgoCD Applications reference charts by registry URL + version constraint
5. `update-charts.yaml` updates the version reference, triggering ArgoCD sync

This means:
- **`prepare.sh` is retired** — no more rsync, hash computation, sed replacements
- **Charts are immutable, versioned artifacts** — reproducible deployments
- **ArgoCD can use version ranges** (e.g., `~2026.04`) for auto-updates within a minor version

### Migration path (revised for 40 AWS-primary clusters)

#### Phase 0: Foundation (no customer impact)
- Publish charts to OCI registry alongside existing mechanism
- Add ArgoCD bootstrap to `infra` workspace (disabled by default via variable)
- Add Secrets Manager output module to `infra` workspace
- Add External Secrets Operator ArgoCD Application manifest
- Replace `lablabs/eks-cluster-autoscaler` with Karpenter EKS addon (or move to ArgoCD)
- Remove Helm/Kubernetes providers from `infra` workspace

#### Phase 1: Pilot (1 internal/test cluster)
- Enable ArgoCD on pilot cluster
- Deploy `paragon-monitoring` and `paragon-logging` via ArgoCD (lowest risk)
- `terraform state rm` those Helm releases from pilot's paragon workspace
- Validate Slack notifications, drift detection, self-healing

#### Phase 2: Expand pilot (same cluster)
- Move ingress controller, metrics-server, node-termination-handler to ArgoCD
- Move `paragon-onprem` to ArgoCD
- Move managed-sync to ArgoCD (if enabled on pilot)
- Move Hoop agent to ArgoCD
- Validate full deployment lifecycle: upgrade, rollback, drift correction

#### Phase 3: Consolidate pilot workspace
- Move `alb/`, `uptime/`, `monitors/`, `hoop-connections/` into `infra` workspace
- Eliminate `paragon` workspace on pilot cluster
- Validate single-workspace Spacelift stack

#### Phase 4: Roll out to remaining AWS clusters (batched)
- Migrate in batches of ~5-10 clusters
- Each batch: enable ArgoCD, `terraform state rm` Helm releases, validate
- Consolidate to single workspace per batch
- Leverage ArgoCD ApplicationSet for batch operations

#### Phase 5: Azure and GCP clusters
- Adapt ArgoCD Application manifests for Azure (NGINX ingress, cert-manager) and GCP (GKE ingress)
- Same phased migration pattern

#### Phase 6: Cleanup
- Remove `paragon` workspace directories from all providers
- Retire `prepare.sh`
- Update `enterprise-deployments` repo Spacelift stacks to single workspace
- Update documentation

### ArgoCD Application structure

```yaml
# app-of-apps.yaml — root Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: paragon
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/useparagon/enterprise
    path: argocd/apps
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      selfHeal: true
      prune: true

---
# argocd/apps/paragon-onprem.yaml — child Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: paragon-onprem
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  project: default
  sources:
    - repoURL: oci://ghcr.io/useparagon/charts  # or ECR
      chart: paragon-onprem
      targetRevision: "2026.04.*"  # auto-update within patch
      helm:
        valueFiles:
          - $values/customers/acme/values.yaml
    - repoURL: https://github.com/useparagon/enterprise-deployments
      ref: values
      targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: paragon
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 3
      backoff:
        duration: 30s
        factor: 2
```

### Slack notifications configuration

```yaml
# ArgoCD Notifications ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  template.app-sync-succeeded: |
    slack:
      attachments: |
        [{
          "color": "#18be52",
          "title": "{{.app.metadata.name}} synced",
          "text": "Application {{.app.metadata.name}} synced to {{.app.status.sync.revision}}"
        }]
  template.app-sync-failed: |
    slack:
      attachments: |
        [{
          "color": "#E96D76",
          "title": "{{.app.metadata.name}} sync failed",
          "text": "Application {{.app.metadata.name}} failed to sync"
        }]
  trigger.on-sync-succeeded: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-sync-succeeded]
  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [app-sync-failed]
```

---

## Risks and Considerations

### Secrets management transition (highest complexity)

The `variables.tf` merge logic (~200 env vars) is the core complexity. Strategy:
- **Keep the same Terraform logic**, but change the output target from `helm_values → helm_release` to `computed_config → aws_secretsmanager_secret`
- The `helm-config/secrets.tf` module's `random_password`/`tls_private_key` values are in Terraform state. For existing clusters, import these values into Secrets Manager during migration (read from state, write to SM). For new clusters, generate fresh values.
- **Validate:** Diff the Secrets Manager content against the current `kubernetes_secret` data to ensure no values were lost.

### ALB/DNS dependency on ingress controller

The `alb/` module currently depends on `helm_release.ingress` (to wait for the ALB to exist before creating DNS records). With ArgoCD deploying ingress, the ALB creation is asynchronous. Options:
- Use `data.aws_lb` with a retry/wait mechanism in Terraform
- Create the ALB pre-provisioned in Terraform and have the ingress controller adopt it (AWS LB Controller supports this via annotations)
- Accept eventual consistency — DNS records can be created pointing to the expected ALB name; they resolve once ArgoCD deploys ingress

### State migration for 40 clusters

State migration requires two operations per cluster: **`terraform state rm`** to remove K8s/Helm resources from the `paragon` workspace, and **`terraform import`** to bring cloud-API resources into the `infra` workspace. The import step is critical — without it, the next `terraform apply` on `infra` would attempt to create resources that already exist, causing conflicts or destruction.

#### Migration strategy overview

The migration is a three-step process per cluster:

1. **`terraform import`** cloud-API resources into the `infra` workspace (new module addresses)
2. **`terraform state rm`** all resources from the `paragon` workspace (both K8s-bound and cloud-API)
3. **`terraform plan`** on both workspaces to verify zero-diff (no changes planned)

Step 1 must happen before step 2 to ensure cloud resources are always managed by at least one workspace. The order prevents any window where a resource is unmanaged.

#### Automation approach

With 40 clusters, manual import is impractical. A migration script should:

1. Read the `paragon` workspace state via `terraform state list` and `terraform state show` to extract resource IDs
2. Map each resource to its new address in the `infra` workspace
3. Generate and execute `terraform import` commands against the `infra` workspace
4. Generate and execute `terraform state rm` commands against the `paragon` workspace
5. Run `terraform plan` on both workspaces to verify zero-diff

This script can be templated and run per-customer via Spacelift or a CI pipeline.

#### AWS resource import inventory

Resources being moved from `module.*` in the `paragon` workspace to new addresses in the `infra` workspace. The `for_each` keys and `count` indices vary per customer — the migration script must enumerate them from the source state.

**`module.alb` → `module.alb` (or `module.dns`) in `infra`**

| Source address | Resource type | Import ID (from state) | Notes |
|---------------|---------------|----------------------|-------|
| `module.alb.aws_route53_zone.paragon` | `aws_route53_zone` | Zone ID (`Z...`) | Core dependency — import first |
| `module.alb.aws_route53_record.microservice["<key>"]` | `aws_route53_record` | `{zone_id}_{fqdn}_{type}` | `for_each` keys = service names from `merge(public_microservices, public_monitors)` |
| `module.alb.aws_route53_record.caa` | `aws_route53_record` | `{zone_id}_{domain}_{CAA}` | Single resource |
| `module.alb.cloudflare_record.nameserver[<n>]` | `cloudflare_record` | `{zone_id}/{record_id}` | `count` = number of NS records; only when Cloudflare is configured |
| `module.alb.module.acm_request_certificate[0].aws_acm_certificate.default[0]` | `aws_acm_certificate` | Certificate ARN | Only when `var.certificate == null` (Terraform-managed cert) |
| `module.alb.module.acm_request_certificate[0].aws_route53_record.default["<domain>"]` | `aws_route53_record` | `{zone_id}_{fqdn}_{type}` | ACM DNS validation records |

**`module.uptime` → `module.uptime` in `infra`**

| Source address | Resource type | Import ID | Notes |
|---------------|---------------|-----------|-------|
| `module.uptime.betteruptime_monitor_group.group[0]` | `betteruptime_monitor_group` | Numeric group ID | Only when `uptime_api_token` is set |
| `module.uptime.betteruptime_monitor.monitor["<key>"]` | `betteruptime_monitor` | Numeric monitor ID | `for_each` keys = microservice names |
| `module.uptime.betteruptime_grafana_integration.webhook[0]` | `betteruptime_grafana_integration` | Numeric integration ID | Single resource |

**`module.monitors[0]` → `module.monitors[0]` in `infra`** (only when `monitors_enabled = true`)

| Source address | Resource type | Import ID | Notes |
|---------------|---------------|-----------|-------|
| `module.monitors[0].aws_iam_user.grafana[0]` | `aws_iam_user` | IAM user name | Only when Grafana keys not supplied in tfvars |
| `module.monitors[0].aws_iam_access_key.grafana[0]` | `aws_iam_access_key` | Access key ID | |
| `module.monitors[0].aws_iam_group.grafana[0]` | `aws_iam_group` | Group name | |
| `module.monitors[0].aws_iam_group_membership.grafana[0]` | `aws_iam_group_membership` | Membership name | |
| `module.monitors[0].aws_iam_group_policy.grafana_ro[0]` | `aws_iam_group_policy` | `{group_name}:{policy_name}` | |
| `module.monitors[0].random_string.grafana_admin_email_prefix[0]` | `random_string` | See note below | |
| `module.monitors[0].random_password.grafana_admin_password[0]` | `random_password` | See note below | |
| `module.monitors[0].random_string.pgadmin_admin_email_prefix[0]` | `random_string` | See note below | |
| `module.monitors[0].random_password.pgadmin_admin_password[0]` | `random_password` | See note below | |

**`module.managed_sync_config[0]` → `module.managed_sync_config[0]` in `infra`** (only when `managed_sync_enabled = true`)

| Source address | Resource type | Import ID | Notes |
|---------------|---------------|-----------|-------|
| `module.managed_sync_config[0].random_string.postgres_username["openfga"]` | `random_string` | See note below | `for_each` over `["openfga", "sync_instance", "sync_project"]` |
| `module.managed_sync_config[0].random_string.postgres_username["sync_instance"]` | `random_string` | | |
| `module.managed_sync_config[0].random_string.postgres_username["sync_project"]` | `random_string` | | |
| `module.managed_sync_config[0].random_password.postgres_password["openfga"]` | `random_password` | | Same `for_each` keys |
| `module.managed_sync_config[0].random_password.postgres_password["sync_instance"]` | `random_password` | | |
| `module.managed_sync_config[0].random_password.postgres_password["sync_project"]` | `random_password` | | |
| `module.managed_sync_config[0].random_string.queue_exporter_username` | `random_string` | | Single resource |
| `module.managed_sync_config[0].random_password.queue_exporter_password` | `random_password` | | |
| `module.managed_sync_config[0].random_string.openfga_preshared_key` | `random_string` | | |
| `module.managed_sync_config[0].tls_private_key.managed_sync_signing_key` | `tls_private_key` | Not importable — see note below | |

**`module.hoop` → `module.hoop_connections` in `infra`** (cloud-API-only resources)

| Source address | Resource type | Import ID | Notes |
|---------------|---------------|-----------|-------|
| `module.hoop.aws_iam_role.hoop_support[0]` | `aws_iam_role` | Role name | Only when OIDC provider ARN is set |
| `module.hoop.aws_iam_role_policy_attachment.hoop_support[0]` | `aws_iam_role_policy_attachment` | `{role_name}/{policy_arn}` | |
| `module.hoop.hoop_connection.all_connections["<key>"]` | `hoop_connection` | Connection ID from Hoop API | `for_each` keys vary per customer |
| `module.hoop.hoop_connection.postgres_connections["<key>"]` | `hoop_connection` | Connection ID | `for_each` keys vary per customer |
| `module.hoop.hoop_plugin_connection.custom_connections_access_control["<key>"]` | `hoop_plugin_connection` | Plugin connection ID | |
| `module.hoop.hoop_plugin_connection.default_connections_access_control["<key>"]` | `hoop_plugin_connection` | Plugin connection ID | |
| `module.hoop.hoop_plugin_connection.postgres_connections_access_control["<key>"]` | `hoop_plugin_connection` | Plugin connection ID | |
| `module.hoop.hoop_plugin_config.slack[0]` | `hoop_plugin_config` | Plugin config ID | Only when Slack is enabled |
| `module.hoop.hoop_plugin_connection.slack["<key>"]` | `hoop_plugin_connection` | Plugin connection ID | |

#### Azure and GCP differences

Azure and GCP have the same general pattern but with:
- **`module.dns`** (Cloudflare records) instead of `module.alb` (Route53/ACM)
- **No IAM resources** in Azure `module.monitors` or `module.hoop` (just `random_*` resources)
- **GCP-specific IAM** in `module.hoop`: `google_service_account`, `google_project_iam_member`, `google_service_account_iam_member`

#### Special handling for `random` and `tls` resources

`random_string`, `random_password`, and `tls_private_key` resources are **stateful** — their values exist only in Terraform state. These are the most sensitive resources to migrate because:

- **`random_*` import:** The `random` provider supports import, but the imported resource will generate a **new** random value on the next `apply` unless the state matches exactly. The correct approach is to use **`terraform state mv`** (state-to-state transfer) rather than `import`:

  ```bash
  # Extract from paragon state, inject into infra state
  terraform state pull -state=paragon.tfstate | \
    jq '.resources[] | select(.module == "module.managed_sync_config[0]")' > extracted.json
  # Then terraform state push into infra (with address remapping)
  ```

  Alternatively, use the **`terraform_remote_state`** data source during a transition period to read values from the paragon workspace state before removing it.

- **`tls_private_key` import:** The `tls` provider **does not support import** for `tls_private_key`. The private key exists only in state. Options:
  1. **`terraform state mv`** from paragon to infra state (requires direct state manipulation)
  2. **Read the key from state before migration,** write it to AWS Secrets Manager, and have the new Terraform config read it from there instead of generating it
  3. **Accept key rotation** for managed-sync signing keys — generate new keys during migration and update the dependent services. This is simpler but requires coordinating the key change with the managed-sync deployment.

  Recommendation: Option 2 — extract the existing key into Secrets Manager. This is already aligned with the broader move to External Secrets Operator.

#### Recommended migration script outline

```bash
#!/bin/bash
# migrate-customer.sh <customer-org> <cloud-provider>
# Run per customer to migrate state from paragon → infra workspace

set -euo pipefail
ORG="$1"
CLOUD="$2"
PARAGON_DIR="${CLOUD}/workspaces/paragon"
INFRA_DIR="${CLOUD}/workspaces/infra"

# Phase 1: Extract resource IDs from paragon state
echo "=== Extracting resource IDs from paragon workspace ==="
cd "$PARAGON_DIR"

# Get all resource addresses and their IDs
terraform state list | while read -r addr; do
  # Filter to cloud-API-only resources (skip helm_release, kubernetes_*)
  case "$addr" in
    *helm_release*|*kubernetes_*|*kubectl_manifest*|*time_sleep*) continue ;;
  esac
  echo "$addr"
done > /tmp/resources_to_move.txt

# For each resource, extract its import ID
while read -r addr; do
  terraform state show -json "$addr" | jq -r '{address: .address, id: .values.id // .values.arn // .values.zone_id}' >> /tmp/import_ids.json
done < /tmp/resources_to_move.txt

# Phase 2: Import into infra workspace
echo "=== Importing resources into infra workspace ==="
cd "../../$INFRA_DIR"

# Map old addresses → new addresses and import
# (address mapping depends on the new module structure)
while read -r line; do
  OLD_ADDR=$(echo "$line" | jq -r '.address')
  IMPORT_ID=$(echo "$line" | jq -r '.id')
  NEW_ADDR=$(map_address "$OLD_ADDR")  # custom function for address remapping

  terraform import "$NEW_ADDR" "$IMPORT_ID"
done < /tmp/import_ids.json

# Phase 3: Handle random/tls resources via state manipulation
echo "=== Migrating stateful resources (random, tls) ==="
# These require terraform state mv or state pull/push
# ... (see detailed handling above)

# Phase 4: Remove all resources from paragon state
echo "=== Removing resources from paragon workspace ==="
cd "../../$PARAGON_DIR"

terraform state list | while read -r addr; do
  terraform state rm "$addr"
done

# Phase 5: Verify
echo "=== Verifying zero-diff on both workspaces ==="
cd "../../$INFRA_DIR"
terraform plan -detailed-exitcode  # exit code 0 = no changes

cd "../../$PARAGON_DIR"
terraform plan -detailed-exitcode  # should show empty plan (no resources)

echo "=== Migration complete for $ORG ==="
```

#### Migration order and batching

Given 40 clusters:

1. **Pilot cluster (1):** Full dry run. Execute migration script, verify zero-diff, validate all resources are intact. Document any edge cases.
2. **Internal clusters (2-3):** Migrate a small batch of internal/test clusters. Soak for 1-2 days.
3. **Production batches (5-10 per batch):** Roll out in batches. Between batches, verify no regressions.
4. **Stragglers:** Handle any clusters with unique configurations (custom Hoop connections, non-standard monitors, etc.) individually.

#### Rollback plan

If migration fails for a cluster:
1. The paragon workspace state still exists (until step 4) — `terraform state rm` can be undone by re-importing
2. The infra workspace imports can be reverted with `terraform state rm`
3. No real resources are created or destroyed during migration — only state files change
4. Worst case: restore both state files from S3 versioned backups (S3 backend supports versioning)

### ArgoCD availability

ArgoCD is a critical-path component for deployments. Mitigations:
- ArgoCD runs as a highly-available deployment (3 replicas by default)
- If ArgoCD is down, existing workloads continue running — only new deployments are blocked
- ArgoCD can manage its own upgrades (self-managing Application)
- Hoop provides audited access to each cluster's ArgoCD for troubleshooting

### Managed sync complexity

`helm-config/secrets.tf` generates substantial config for managed-sync (Kafka, Postgres, Redis, OpenFGA, storage, monitoring — 100+ keys). This module stays in Terraform (moved to `infra`) and writes to Secrets Manager. ESO syncs to `paragon-managed-sync-secrets`. The managed-sync chart already expects to read from that secret name — no chart changes needed.

Since managed sync is only enabled for a subset of customers, this complexity only applies during migration for those clusters.

---

## Summary: Evaluation Matrix (Updated)

| Criterion | Current (Terraform Helm) | Proposed (ArgoCD + ESO) |
|-----------|--------------------------|-------------------------|
| Terraform workspaces per customer | 2 (infra + paragon) | **1 (infra only)** |
| K8s API access from CI | Required (both workspaces on AWS) | **Not required (any cloud)** |
| Public K8s API required | Yes (or VPC runner) | **No — bootstrap tunneled via cloud API on all 3 clouds** |
| Spacelift plan required | Enterprise (private runners) or public K8s API | **Starter (public cloud APIs only)** |
| Upgrade frequency achievable | Monthly (manual per-customer) | **Daily (Git push → auto-sync)** |
| Upgrade effort per release | `prepare.sh` + `terraform apply` × 40 clusters | **Single Git commit** |
| Rollback | Complex (state revert + re-apply × 40) | **One-click per cluster, automatable** |
| Drift detection | None | **Continuous (3 min interval)** |
| Self-healing | None | **Automatic (`selfHeal: true`)** |
| Config duplication | High (TF locals + values.yaml + set blocks) | **Single source (Secrets Manager + values file)** |
| Secrets management | Terraform state (S3) | **Cloud-native secret managers (AWS SM, Azure KV, GCP SM)** |
| Deployment observability | Terraform logs in Spacelift | **ArgoCD UI + Slack notifications** |
| Chart management | `prepare.sh` + in-repo copies | **OCI registry with semver** |
| Node autoscaling | Cluster Autoscaler (Helm) + NTH (Helm) | **ArgoCD-managed (Karpenter migration optional)** |
| Adding new customer | 2 Spacelift stacks + manual setup | **1 Spacelift stack + auto-deploy** |
