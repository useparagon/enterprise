# ArgoCD Deployment Evaluation

## Executive Summary

This document evaluates replacing the Terraform Helm provider (used in each cloud provider's `paragon` workspace) with ArgoCD for managing Helm chart deployments. The goal is to eliminate the need for Terraform to access the Kubernetes API, enable GitOps-based upgrades and rollbacks, and simplify multi-customer deployment management.

**Recommendation:** ArgoCD can replace the `paragon` workspace's Helm release management and deliver meaningful improvements across all evaluation criteria. The `infra` workspace remains unchanged — it provisions cloud infrastructure (VPC, databases, K8s cluster, storage) and does not require K8s API access. The `paragon` workspace can be decomposed: some resources stay in Terraform (ALB certificates, DNS, uptime monitors, Grafana IAM), while all Helm releases and in-cluster resources move to ArgoCD.

---

## Current Architecture Analysis

### How it works today

```
┌─────────────────────────────────────────────────────────────────────┐
│ Terraform Runner (Spacelift / local)                                │
│                                                                     │
│  infra workspace ──► VPC, K8s cluster, Postgres, Redis, S3/GCS/Blob│
│       │                                                             │
│       ▼ outputs (infra-output.json)                                 │
│                                                                     │
│  paragon workspace ──► K8s API ──► helm_release resources           │
│       │                    ▲        (paragon-onprem, logging,       │
│       │                    │         monitoring, managed-sync,       │
│       │                    │         ingress, metrics-server, hoop)  │
│       │                    │                                        │
│       │              Requires direct network                        │
│       │              access to K8s API                              │
│       │              (public endpoint or VPC runner)                │
│       │                                                             │
│       └──► kubernetes_secret, kubernetes_namespace,                  │
│            kubernetes_config_map, kubernetes_storage_class           │
└─────────────────────────────────────────────────────────────────────┘
```

### Pain points identified

| Problem | Details |
|---------|---------|
| **Dual config locations** | Environment variables are defined in `.secure/values.yaml` (Helm values), merged/augmented in `variables.tf` locals (200+ env vars constructed from `infra_vars` + `helm_vars`), and cloud-specific values injected via `set`/`set_sensitive` in `helm.tf`. A single config change may require touching 2-3 files. |
| **K8s API access requirement** | The `paragon` workspace's Helm and Kubernetes providers connect directly to the cluster API (EKS endpoint + auth token, AKS kubeconfig fields, GKE endpoint + OAuth token). This means the K8s API must be publicly accessible or the Terraform runner must be inside the VPC. |
| **VPC runner cost** | Running Terraform inside the VPC requires Spacelift private workers (enterprise plan), self-hosted runners, or a public K8s API — all undesirable. |
| **No GitOps / rollback** | Deployments are imperative (`terraform apply`). Rolling back means reverting state + re-applying. No automatic drift detection or self-healing. |
| **Upgrade friction** | Upgrades require running `prepare.sh`, updating `VERSION` in values.yaml, then `terraform plan/apply` on both workspaces — a multi-step manual process. |

---

## Proposed Architecture with ArgoCD

```
┌──────────────────────────────────────────────────────────────┐
│ Terraform Runner (Spacelift Starter — public API only)       │
│                                                              │
│  infra workspace ──► VPC, K8s cluster, Postgres, Redis, S3   │
│       │              + ArgoCD Helm release (bootstrap)        │
│       │              + ExternalSecrets operator (optional)    │
│       │                                                      │
│       ▼ outputs (infra-output.json)                          │
│                                                              │
│  paragon workspace (reduced) ──► Cloud-only resources:       │
│       ALB certificates, DNS records, uptime monitors,        │
│       Grafana IAM, Hoop API connections                      │
│       (NO K8s API access needed)                             │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ ArgoCD (runs inside the K8s cluster)                         │
│                                                              │
│  Watches this Git repo ──► Deploys Helm charts:              │
│    • paragon-onprem (all microservices)                       │
│    • paragon-logging (fluent-bit + openobserve)              │
│    • paragon-monitoring (grafana, prometheus, exporters)      │
│    • managed-sync (when enabled)                             │
│    • bootstrap/ingress (ingress controller, cert-manager)    │
│    • hoop agent                                              │
│                                                              │
│  Also manages:                                               │
│    • Kubernetes Secrets (via ExternalSecrets or SealedSecrets)│
│    • Namespace, ConfigMaps, StorageClass                     │
│    • Drift detection + self-healing                          │
│    • Automatic sync on Git push                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Answering the Key Questions

### 1. Can we eliminate the Terraform Helm provider entirely?

**Yes, for the `paragon` workspace.** All `helm_release` resources in `{aws,azure,gcp}/workspaces/paragon/helm/` can be replaced by ArgoCD `Application` CRDs that point to the same charts in this repo.

**What moves to ArgoCD:**
- `helm_release.paragon_on_prem` — the main microservices umbrella chart
- `helm_release.paragon_logging` — fluent-bit + openobserve
- `helm_release.paragon_monitoring` — grafana, prometheus, exporters
- `helm_release.managed_sync` — managed sync chart (when enabled)
- `helm_release.ingress` — AWS LB controller / NGINX ingress / GKE ingress
- `helm_release.metricsserver` — metrics server (AWS)
- `helm_release.cert_manager` — cert-manager (Azure)
- `helm_release.hoopagent` — hoop agent
- `kubernetes_namespace.paragon` — namespace creation
- `kubernetes_secret.docker_login` — docker pull secret
- `kubernetes_secret.paragon_secrets` — application secrets
- `kubernetes_config_map.feature_flag_content` — feature flags
- `kubernetes_storage_class_v1.gp3_encrypted` — storage class (AWS)
- `module.aws_node_termination_handler` — spot termination handler

**What stays in Terraform (no K8s API needed):**
- `module.alb` — ACM certificate creation/validation, DNS records (uses AWS API, not K8s)
- `module.uptime` — BetterStack uptime monitors (uses BetterStack API)
- `module.monitors` — IAM users for Grafana CloudWatch access (uses AWS API)
- `module.hoop` (partially) — Hoop API connections (uses Hoop API); the `helm_release.hoopagent` moves to ArgoCD

**Caveat — the `infra` workspace:** The `infra/cluster/` module on AWS uses the Kubernetes/Helm provider for bootstrapping (e.g. installing the EBS CSI driver via the EKS module). This is a one-time cluster setup concern and stays in Terraform. It's a different workspace that runs during initial provisioning only.

### 2. Can we remove the need for private VPC Terraform execution?

**Yes.** Today, the `paragon` workspace requires K8s API access because of the Helm and Kubernetes providers. With ArgoCD handling all in-cluster resources, the reduced `paragon` workspace only calls cloud provider APIs (AWS/Azure/GCP) and third-party APIs (BetterStack, Hoop) — none of which require VPC access.

The `infra` workspace already works without K8s API access for the bulk of its resources. The one exception is the cluster bootstrap step (EKS module Kubernetes provider), which typically runs once during initial setup and can use the public K8s endpoint temporarily.

### 3. Does GitOps provide reliable, automated upgrades?

**Yes.** Here's how the upgrade workflow would change:

| Step | Current (Terraform) | Proposed (ArgoCD) |
|------|---------------------|-------------------|
| 1 | Run `prepare.sh` to update charts and compute hashes | Same — `prepare.sh` or GitHub Actions workflow updates charts in-repo |
| 2 | Update `VERSION` in `.secure/values.yaml` | Update `VERSION` in values file committed to Git (or in ArgoCD `Application` spec) |
| 3 | Run `terraform plan` + `terraform apply` in paragon workspace | **Automatic** — ArgoCD detects Git changes and syncs |
| 4 | Wait for Terraform to complete (~15-20 min timeout per release) | ArgoCD applies changes with configurable sync waves and health checks |
| 5 | If failure: manually debug Terraform state | If failure: ArgoCD shows sync status, can auto-rollback |

**Key improvements:**
- **No manual `terraform apply` step** — Git push triggers deployment
- **Sync waves** ensure ordering (ingress → secrets → paragon-onprem → logging → monitoring)
- **Health checks** prevent unhealthy deployments from progressing
- **Automatic retry** on transient failures
- **Existing `update-charts.yaml` GitHub Action** can be extended to commit version bumps, triggering automatic deployment

### 4. Does this improve rollback and drift handling?

**Significantly.**

**Rollback:**
- **Current:** Requires reverting Terraform state files, re-running `terraform apply`, and dealing with potential state drift. The Helm provider's `atomic = true` helps with individual release failures, but cross-release rollback is manual.
- **With ArgoCD:** `argocd app rollback <app> <revision>` or clicking "Rollback" in the UI. ArgoCD maintains a history of all synced Git revisions. Rolling back to a previous revision re-deploys the exact chart + values from that commit.

**Drift detection:**
- **Current:** None. If someone `kubectl edit`s a deployment or a Helm release is manually modified, Terraform has no idea until the next `plan` (which may be weeks later).
- **With ArgoCD:** Continuous drift detection. ArgoCD compares live cluster state against the desired state in Git every 3 minutes (default). Drift is visible in the UI and can be auto-corrected (`selfHeal: true`).

### 5. Does this allow us to remain on Spacelift Starter?

**Yes.** Spacelift Starter supports public Terraform operations. With ArgoCD handling all K8s-facing work:

- `infra` workspace: provisions cloud infrastructure via cloud provider APIs (public) ✓
- `paragon` workspace (reduced): manages cloud-only resources via cloud provider APIs (public) ✓
- ArgoCD: runs inside the cluster, no external runner needed ✓

No private workers, no VPC runners, no enterprise plan required.

### 6. Does GitOps simplify multi-customer application management?

**Yes, substantially.**

**Current model per customer:**
1. Clone/fork this repo
2. Configure `.secure/values.yaml` and `.secure/infra-output.json`
3. Run `terraform apply` in infra workspace
4. Run `terraform apply` in paragon workspace
5. For upgrades: repeat steps 1-4 manually

**Proposed model with ArgoCD:**

**Option A: App-of-Apps pattern (recommended)**
- One ArgoCD instance per customer cluster (see Q7 below)
- A "root" `Application` deploys child `Application` resources for each chart
- Customer-specific values stored in a per-customer branch or overlay directory
- Upgrades: update chart versions in Git → all customers auto-deploy (or use Progressive Delivery)

**Option B: ApplicationSet with Git Generator**
- If managing multiple customers from a central ArgoCD, `ApplicationSet` with a Git generator can template `Application` resources per customer directory
- Each customer gets a directory like `customers/<org>/values.yaml`
- Adding a new customer = adding a directory with their values

Both options reduce per-customer upgrade effort from "manual Terraform apply per customer" to "Git commit."

### 7. Should each cluster have its own ArgoCD instance?

**Yes — strongly recommended** for this deployment model, for several reasons:

| Consideration | Dedicated ArgoCD per cluster | Central ArgoCD |
|---------------|------------------------------|----------------|
| **Network access** | ArgoCD runs in the cluster it manages — no cross-VPC connectivity needed | Central ArgoCD needs network access to every customer cluster (complex, security concern) |
| **Customer isolation** | Complete isolation — each customer's ArgoCD only sees their cluster | Central instance has credentials for all clusters (blast radius) |
| **Failure domain** | ArgoCD failure affects only one customer | Central failure affects all customers |
| **Credential management** | ArgoCD uses in-cluster ServiceAccount — no external credentials | Needs kubeconfig/tokens for every remote cluster |
| **Sovereignty** | Runs in customer's own cloud account | May violate data residency requirements |
| **Scalability** | No single bottleneck | Central ArgoCD must handle all clusters |

**Recommended approach:**
- Install ArgoCD as part of the `infra` workspace (Terraform installs the ArgoCD Helm chart during cluster bootstrap — this is a one-time operation)
- ArgoCD's `Application` CRDs are stored in this Git repo
- Each customer cluster's ArgoCD watches this repo (same branch or customer-specific branch)
- ArgoCD manages itself after initial bootstrap (ArgoCD managing its own `Application`)

---

## Implementation Approach

### What changes in this repo

#### New: ArgoCD Application manifests

A new top-level directory (e.g. `argocd/`) would contain:

```
argocd/
├── base/                          # Base Application manifests
│   ├── bootstrap.yaml             # Ingress controller, cert-manager, etc.
│   ├── paragon-onprem.yaml        # Main microservices
│   ├── paragon-logging.yaml       # Logging stack
│   ├── paragon-monitoring.yaml    # Monitoring stack
│   ├── managed-sync.yaml          # Managed sync (optional)
│   └── hoop.yaml                  # Hoop agent (optional)
├── overlays/
│   ├── aws/                       # AWS-specific values/patches
│   ├── azure/                     # Azure-specific values/patches
│   └── gcp/                       # GCP-specific values/patches
└── app-of-apps.yaml               # Root Application that deploys all others
```

#### Changed: `infra` workspace

Add ArgoCD installation:
```hcl
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  # ... minimal config, ArgoCD manages itself after this
}
```

#### Changed: `paragon` workspace

Remove:
- All `helm_release` resources
- All `kubernetes_*` resources  
- Helm and Kubernetes providers
- `helm/` submodule entirely

Keep (cloud-API-only resources):
- `alb/` — certificate management, DNS
- `monitors/` — IAM for Grafana
- `uptime/` — BetterStack monitors
- `hoop/` (API connections only, not the Helm release)

#### Changed: Values management

Currently, Terraform merges `.secure/values.yaml` + `infra-output.json` + computed locals into a single `helm_values` map. With ArgoCD, this merging must happen differently:

**Option A: Pre-computed values file (simplest)**
- A script (or GitHub Action) takes `infra-output.json` + `.secure/values.yaml` and produces a complete `values.yaml` committed to a customer branch
- ArgoCD uses this single file
- Pro: Simple, transparent, auditable in Git history
- Con: Requires a "compile" step; secrets in Git (mitigated by SealedSecrets/SOPS/ExternalSecrets)

**Option B: ArgoCD + External Secrets Operator**
- Chart values contain non-secret config only
- Secrets are stored in the cloud secret manager (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager)
- External Secrets Operator syncs cloud secrets → K8s Secrets
- ArgoCD deploys the charts, referencing the K8s Secrets
- Pro: No secrets in Git; aligns with cloud-native secret management
- Con: Additional operator to manage; more moving parts

**Option C: Helm value files + ArgoCD multi-source**
- ArgoCD Application uses [multiple sources](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/) — one for the chart, one for the values file (from a separate repo or path)
- Pro: Clean separation of chart code and customer config
- Con: Requires ArgoCD 2.6+

**Recommendation:** Option B (External Secrets Operator) combined with Option C (multi-source). This eliminates secrets from Git entirely and cleanly separates concerns. The current pattern of Terraform writing `kubernetes_secret` resources maps directly to External Secrets syncing from cloud secret stores.

### Migration path

The migration can be done incrementally per cloud provider, per customer:

1. **Phase 0: ArgoCD bootstrap** — Add ArgoCD Helm release to `infra` workspace. All three cloud providers.
2. **Phase 1: Non-critical charts first** — Move `paragon-monitoring` and `paragon-logging` to ArgoCD. These are lowest risk.
3. **Phase 2: Ingress and bootstrap** — Move ingress controller and cert-manager to ArgoCD.
4. **Phase 3: Core application** — Move `paragon-onprem` to ArgoCD. This is the highest-value, highest-risk migration.
5. **Phase 4: Managed sync** — Move `managed-sync` to ArgoCD.
6. **Phase 5: Cleanup** — Remove Helm/Kubernetes providers from `paragon` workspace. Simplify the workspace to cloud-API-only resources.

Each phase can be tested on a single customer before rolling out broadly.

---

## Risks and Considerations

### Secrets management transition

The biggest complexity is how `variables.tf` currently computes ~200 environment variables by merging `infra_vars` and `helm_vars`. This logic (in `aws/workspaces/paragon/variables.tf` lines 607-834 and equivalents for Azure/GCP) must be replicated outside Terraform. Options:

- **Script-based:** Extend `prepare.sh` or `generate-tfvars.mjs` to produce a complete values file
- **External Secrets:** Store computed values in cloud secret managers during `infra` workspace apply
- **Init container:** A Kubernetes init container or operator that reads infra outputs and generates config

### The `helm-config` module complexity

The `helm-config/secrets.tf` module (used for managed sync) generates secrets by merging infra outputs with helm values and generating random credentials (`random_password`, `random_string`, `tls_private_key`). This stateful generation needs careful migration — the random values are stored in Terraform state and must not change during migration.

### Cloud-specific ingress differences

Each cloud handles ingress differently:
- **AWS:** ALB Controller Helm release + ALB `Ingress` annotations
- **Azure:** NGINX Ingress Controller + cert-manager + `kubectl_manifest` for `ClusterIssuer`
- **GCP:** `kubectl_manifest` for GKE-native ingress + `FrontendConfig`/`ManagedCertificate`

ArgoCD handles all of these, but the cloud-specific Application manifests will differ.

### ArgoCD itself needs management

ArgoCD is another piece of infrastructure to maintain. However:
- It's a mature CNCF graduated project
- It runs as a Helm release in the cluster
- It can manage its own upgrades (self-managing pattern)
- The operational overhead is low compared to the current Terraform-based deployment complexity

### State migration

Existing `helm_release` resources have Terraform state. Migration requires:
1. `terraform state rm` the Helm releases from Terraform state
2. Import the running Helm releases into ArgoCD
3. ArgoCD adopts existing resources without disruption

ArgoCD supports adopting existing resources via the `argocd.argoproj.io/managed-by` annotation and `Replace=true` sync option.

---

## Summary: Evaluation Matrix

| Criterion | Current (Terraform Helm) | Proposed (ArgoCD) |
|-----------|--------------------------|-------------------|
| K8s API access from CI | Required (public or VPC runner) | Not required |
| Spacelift plan | Enterprise (private runners) or public K8s API | Starter (public cloud APIs only) |
| Upgrade automation | Manual `terraform apply` | Automatic on Git push |
| Rollback | Complex (state revert + re-apply) | One-click / one-command |
| Drift detection | None | Continuous (every 3 min) |
| Self-healing | None | Automatic with `selfHeal: true` |
| Config duplication | High (TF locals + values.yaml + set blocks) | Lower (single values source per app) |
| Multi-customer scaling | Per-customer `terraform apply` | Git-driven, automatable |
| Observability | Terraform logs | ArgoCD UI + CLI + notifications |
| Secrets in Git | N/A (Terraform state) | Solved via External Secrets Operator |

---

## Follow-up Questions

To refine this evaluation further, it would be helpful to clarify:

1. **How many customer clusters are actively deployed today?** This affects the migration timeline and whether an ApplicationSet approach is worthwhile vs. per-customer branches.

2. **Is there an existing secret management solution (AWS Secrets Manager, HashiCorp Vault, etc.) in use?** This determines whether External Secrets Operator can leverage existing secret stores or if new ones need to be created.

3. **Is the `managed_sync_enabled` feature used by all customers or a subset?** The `helm-config` module's stateful secret generation (random passwords, TLS keys) is the most complex part of the migration. Understanding adoption helps prioritize.

4. **Are there customers on all three cloud providers (AWS, Azure, GCP), or is one dominant?** This helps prioritize which cloud provider to migrate first.

5. **How frequently are upgrades pushed to customers today?** If upgrades are infrequent, the GitOps automation benefit is lower-priority. If frequent, it's high-priority.

6. **Is there a preference for how customer-specific config is organized?** Options include:
   - Per-customer branches in this repo
   - A separate "config" repo with per-customer directories
   - Per-customer values files in a `.secure/` convention

7. **Does Paragon's managed enterprise offering (mentioned in README) use the same Terraform approach?** If so, ArgoCD could benefit that workflow too, enabling the managed team to push upgrades via Git rather than running Terraform per customer.

8. **Are there any compliance/regulatory requirements around who can deploy to customer clusters?** ArgoCD's RBAC and audit logging may need to satisfy specific compliance frameworks.

9. **Is the `hoop` module deployed to all customers?** The Hoop agent Helm release is straightforward to move to ArgoCD, but the Hoop API connections (managed via the Hoop Terraform provider) must remain in Terraform.

10. **Would you like ArgoCD notifications (Slack, email) on sync success/failure?** ArgoCD supports rich notification integrations that could replace manual monitoring of Terraform apply outputs.

11. **Is the existing GitHub Actions workflow (`update-charts.yaml`) triggered automatically or manually?** Understanding the current automation level helps design the GitOps trigger chain.

12. **What is the current state management for Terraform? (Spacelift managed, S3 backend, Terraform Cloud?)** The `main.tf.example` pattern suggests varied backends. Understanding this helps plan the state migration for removing Helm releases from Terraform.
