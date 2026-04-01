# ArgoCD Deployment Evaluation

## Executive Summary

This document evaluates replacing the Terraform Helm provider (used in each cloud provider's `paragon` workspace) with ArgoCD for managing Helm chart deployments across 40 customer clusters (primarily AWS). The goal is to eliminate the need for Terraform to access the Kubernetes API, enable daily GitOps-based upgrades (up from monthly), provide rollback and drift detection, and stay on Spacelift Starter.

**Recommendation:** Adopt ArgoCD with External Secrets Operator (ESO). The entire `paragon` workspace can be eliminated by moving cloud-API-only resources (ALB, DNS, uptime, monitors, Hoop API connections) into the `infra` workspace and moving all Helm releases / K8s resources to ArgoCD. The `infra` workspace's Helm/Kubernetes provider dependency (cluster-autoscaler module) can also be removed by switching to the EKS-managed Karpenter addon. ArgoCD itself can be bootstrapped via an EKS addon (the ArgoCD EKS add-on from the AWS marketplace) or a single `helm_release` during initial cluster provisioning.

This results in a single Terraform workspace (`infra`) that only calls cloud provider APIs — no K8s API access, no private runners, Spacelift Starter is sufficient.

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

## Answering Your Two New Questions

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

Each cluster has Terraform state containing Helm release resources. Migration per cluster:
1. `terraform state rm` all `helm_release.*` and `kubernetes_*` resources
2. Run `terraform apply` (no-op — resources are removed from state)
3. ArgoCD adopts the running workloads

This is safe because we're not destroying resources — just removing them from Terraform's knowledge. The workloads continue running. ArgoCD compares live state against desired state and takes over management.

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
| K8s API access from CI | Required (both workspaces on AWS) | **Not required** |
| Spacelift plan required | Enterprise (private runners) or public K8s API | **Starter (public APIs only)** |
| Upgrade frequency achievable | Monthly (manual per-customer) | **Daily (Git push → auto-sync)** |
| Upgrade effort per release | `prepare.sh` + `terraform apply` × 40 clusters | **Single Git commit** |
| Rollback | Complex (state revert + re-apply × 40) | **One-click per cluster, automatable** |
| Drift detection | None | **Continuous (3 min interval)** |
| Self-healing | None | **Automatic (`selfHeal: true`)** |
| Config duplication | High (TF locals + values.yaml + set blocks) | **Single source (Secrets Manager + values file)** |
| Secrets management | Terraform state (S3) | **AWS Secrets Manager (cloud-native)** |
| Deployment observability | Terraform logs in Spacelift | **ArgoCD UI + Slack notifications** |
| Chart management | `prepare.sh` + in-repo copies | **OCI registry with semver** |
| Adding new customer | 2 Spacelift stacks + manual setup | **1 Spacelift stack + auto-deploy** |
