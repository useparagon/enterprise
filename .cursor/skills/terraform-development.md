# Terraform Development Skill

Use this skill when modifying, testing, or verifying Terraform configurations (`.tf` files), Helm chart templates, or the `prepare.sh` / Node.js helper scripts in this repository.

## Repository Architecture

### Two-Phase Deployment Model

Every cloud provider (AWS, Azure, GCP) uses two Terraform workspaces:

1. **`infra`** — Provisions cloud infrastructure: VPC/VNet/VPC, subnets, Postgres, Redis, Kubernetes cluster, storage buckets, optional Kafka, bastion host.
2. **`paragon`** — Deploys Helm charts to the Kubernetes cluster created by `infra`: installs Paragon microservices, monitoring, logging, DNS, and optional integrations (Hoop, uptime).

The workspaces are coupled via a **JSON file**, not `terraform_remote_state`:

```
infra workspace → terraform output -json → .secure/infra-output.json → paragon workspace
```

The paragon workspace reads this file through `local.infra_vars = jsondecode(file(var.infra_json_path))`. Each key in the JSON corresponds to an infra output name (e.g., `postgres`, `redis`, `minio`, `workspace`, `cluster_name`).

### Directory Layout

```
<provider>/workspaces/
├── infra/
│   ├── main.tf.example      # Provider requirements (no backend block)
│   ├── main.tf               # Generated from example by prepare.sh
│   ├── providers.tf          # Cloud provider auth config
│   ├── variables.tf          # Inputs + locals
│   ├── modules.tf            # Module composition
│   ├── outputs.tf            # Outputs consumed by paragon
│   ├── data.tf               # Data sources
│   ├── vars.auto.tfvars      # Generated placeholder for required vars
│   ├── network/              # VPC/subnets module
│   ├── postgres/             # Database module
│   ├── redis/                # Cache module
│   ├── storage/              # Object storage module
│   ├── cluster/              # Kubernetes cluster module
│   ├── bastion/              # Bastion/jump host module
│   ├── kafka/                # Optional Kafka/event streaming module
│   └── cloudtrail/           # (AWS only) audit logging
├── paragon/
│   ├── main.tf / providers.tf / variables.tf / modules.tf / outputs.tf / data.tf
│   ├── .secure/              # infra-output.json + values.yaml (gitignored)
│   ├── charts/               # Helm charts copied by prepare.sh (gitignored)
│   ├── helm/                 # Helm release module
│   ├── helm-config/          # Managed-sync secret config module
│   ├── alb/ or dns/          # Load balancer / DNS module (varies by provider)
│   ├── monitors/             # Grafana/pgadmin credentials module
│   ├── uptime/               # BetterStack uptime monitors
│   └── hoop/                 # Hoop agent connections/RBAC
```

### Module Structure

All modules are **local path modules** (e.g., `source = "./network"`). No shared module directory exists across providers. Each provider maintains its own modules.

External registry modules used:
- **AWS**: `terraform-aws-modules/eks/aws`, `terraform-aws-modules/kms/aws`, `terraform-aws-modules/iam/aws`, `cloudposse/acm-request-certificate/aws`, `trussworks/cloudtrail/aws`, `lablabs/eks-cluster-autoscaler/aws`, `qvest-digital/aws-node-termination-handler/kubernetes`
- **GCP**: `terraform-google-modules/kubernetes-engine/google//modules/private-cluster`
- **Azure**: No external registry modules (uses native `azurerm` resources directly)

## How to Validate Terraform Changes

### Step 1: Initialize Without Backend

Since backend configs reference remote state stores (S3, GCS, Azure Blob), always init with `-backend=false` for local validation:

```bash
cd <provider>/workspaces/<infra|paragon>
terraform init -backend=false
```

This downloads provider plugins and modules without requiring cloud credentials for state access.

### Step 2: Validate Syntax and Configuration

```bash
terraform validate
```

This catches:
- Syntax errors, missing arguments, type mismatches
- Broken references between resources/modules
- Circular dependencies
- Invalid provider configurations

It does **not** catch:
- Runtime permission errors
- Variable validation rules (those require actual values)
- Issues that only appear during `plan` (e.g., count/for_each with dynamic values)

### Step 3: Format Check

```bash
terraform fmt -check -recursive
```

Checks formatting without modifying files. To auto-fix:

```bash
terraform fmt -recursive
```

### Step 4: Validate All Six Workspaces

After any cross-cutting change, validate all workspaces:

```bash
for provider in aws azure gcp; do
  for ws in infra paragon; do
    echo "=== $provider/$ws ==="
    cd /workspace/$provider/workspaces/$ws
    terraform init -backend=false -upgrade
    terraform validate
    cd /workspace
  done
done
```

Use `-upgrade` when provider version constraints change.

### When terraform plan Is Needed

`terraform plan` requires real cloud credentials and an initialized backend. It is needed to verify:
- Actual resource changes (create/update/destroy)
- Dynamic values (`count`/`for_each` that depend on data sources)
- Provider-specific validation (e.g., instance type availability)
- State drift detection

In this repo, `terraform plan` is an **operator responsibility** (run against real infrastructure), not a local dev task.

## How to Test Changes

### Terraform Changes

| Change Type | Minimum Validation | Recommended Validation |
|---|---|---|
| Add/modify a variable | `terraform validate` on affected workspace(s) | Also check if `generate-tfvars.mjs` correctly handles the new variable |
| Add/modify a module | `terraform validate` + `terraform fmt -check` | Validate all workspaces if the module pattern is shared |
| Add a new resource | `terraform validate` on affected workspace | Review naming pattern (`${var.workspace}-*`), tagging, and conditional creation |
| Change provider versions | `terraform init -backend=false -upgrade` + `terraform validate` | Check `.terraform.lock.hcl` changes |
| Cross-provider change | Validate all 6 workspaces | Compare the change across all three providers for consistency |

### Script Changes (`prepare.sh`, `scripts/*.mjs`)

```bash
# Test prepare.sh for all providers
./prepare.sh -p aws -t <latest-git-tag>
./prepare.sh -p azure -t <latest-git-tag>
./prepare.sh -p gcp -t <latest-git-tag>

# Test generate-tfvars.mjs
node scripts/generate-tfvars.mjs aws/workspaces/infra/variables.tf /tmp/test.tfvars

# Test update-charts.mjs (requires a service-inputs.json from a git tag)
node scripts/update-charts.mjs <path-to-service-inputs.json>
```

### Helm Chart Changes

```bash
# Lint prepared charts (after running prepare.sh)
helm lint <provider>/workspaces/paragon/charts/paragon-logging
helm lint <provider>/workspaces/paragon/charts/paragon-monitoring
helm lint <provider>/workspaces/paragon/charts/paragon-onprem

# Template render (dry-run to check YAML output)
helm template my-release <provider>/workspaces/paragon/charts/paragon-logging
```

Note: `paragon-onprem` and `paragon-monitoring` will show errors about missing `paragon-templates` library chart dependency. This is expected — the dependency is resolved by `helm dependency build` during actual Terraform-driven deployment.

## Key Patterns to Understand

### Conditional Resource Creation

The repo uses two patterns for conditional resources:

**Module-level `count`** for entire feature sets:
```hcl
module "kafka" {
  source = "./kafka"
  count  = var.managed_sync_enabled ? 1 : 0
  # ...
}
```

Access with `module.kafka[0].output_name`. Key feature flags:
- `managed_sync_enabled` — Kafka, managed-sync Helm chart, extra secrets, S3 buckets
- `monitors_enabled` — Grafana, Prometheus, exporters, pgadmin
- `disable_cloudtrail` — AWS CloudTrail (inverted: `count = var.disable_cloudtrail ? 0 : 1`)
- `hoop_enabled` — Hoop agent, connections, RBAC
- `cloudflare_tunnel_enabled` — Zero Trust tunnel on bastion

**Resource-level `count`** for individual resources:
```hcl
resource "aws_s3_bucket" "managed_sync" {
  count  = var.managed_sync_enabled ? 1 : 0
  bucket = "${var.workspace}-managed-sync"
}
```

### Workspace Naming

All providers derive a stable workspace name:
```
paragon-${organization}-${hash_of_cloud_account_id}
```
- AWS: `hash = sha256(aws_account_id)[0:8]`
- Azure: `hash = sha256(subscription_id)[0:8]`
- GCP: `hash = sha256(project_id)[0:8]`

Override with `migrated_workspace` variable. This workspace name prefixes nearly every cloud resource.

### Variable Patterns

- **Required variables** have no `default` — these generate placeholder entries in `vars.auto.tfvars` via `generate-tfvars.mjs`.
- **Feature flags** are `bool` with `default = false` (or `true` for always-on features).
- **Optional credentials** use `default = null` — presence/absence drives conditional logic.
- **Comma-separated lists** (e.g., `ssh_whitelist`, `eks_spot_node_instance_type`) are parsed in `locals` with `split()` + `trimspace()` + `distinct()`.
- **`sensitive = true`** is used on credential variables and connection-info outputs.
- **`validation` blocks** enforce constraints (e.g., `eks_spot_instance_percent` between 0–100).

### Provider-Specific Differences

| Area | AWS | Azure | GCP |
|---|---|---|---|
| Kubernetes | EKS (registry module) | AKS (native resource) | GKE (registry module, private cluster) |
| Database | RDS (`for_each` instances) | Flexible Server (delegated subnet + private DNS) | Cloud SQL (VPC peering) |
| Cache | ElastiCache (cluster + standalone modes) | Azure Cache for Redis | Memorystore |
| Storage | S3 (multi-bucket) | Storage Account (containers) | GCS (per-bucket) |
| Kafka | MSK (SCRAM auth) | Event Hubs (Kafka protocol) | Google Managed Kafka (PLAIN or OAUTHBEARER) |
| DNS/LB | ALB module + Route53/Cloudflare | Cloudflare per-service records | Cloudflare wildcard record |
| Bastion | EC2 ASG + external module | VMSS | MIG + instance template |
| IAM for Hoop | IRSA (OIDC) | None (no cloud IAM) | Workload Identity |
| Tags/Labels | `default_tags` (PascalCase) | `tags` (PascalCase) | `default_labels` (lowercase) |

### Tagging and Labeling

The `providers.tf` in each infra workspace applies default tags/labels automatically:
- AWS/Azure: `Name`, `Environment`, `Creator`, `Organization`
- GCP: `name`, `environment`, `creator`, `organization` (lowercase required by GCP)

Individual resources may add a `Name` tag for workspace-scoped naming (e.g., `"${var.workspace}-vpc"`).

### State Management

- **No backend is declared in the repo** — `main.tf.example` only contains `required_providers`.
- Operators add their own backend (S3, GCS, Azure Blob, Terraform Cloud) by editing `main.tf` (which is gitignored).
- `terraform init -backend=false` is the standard approach for local validation.

### Output-to-Input Data Flow

The critical data flow between workspaces:

```
infra outputs → terraform output -json → .secure/infra-output.json → paragon locals
```

Infra output shape (each key wraps value in `.value`):
```json
{
  "workspace": { "value": "paragon-org-abc12345" },
  "postgres": { "value": { "cerberus": { "host": "...", "port": "5432", ... }, ... } },
  "redis": { "value": { "cache": { "host": "...", "port": 6379, ... }, ... } },
  "minio": { "value": { "public_bucket": "...", "private_bucket": "...", ... } },
  "cluster_name": { "value": "paragon-org-abc12345" }
}
```

Paragon reads with: `local.infra_vars = jsondecode(file(".secure/infra-output.json"))` and accesses values like `local.infra_vars.postgres.value.cerberus.host`.

## Common Modification Scenarios

### Adding a New Microservice

1. Create Helm subchart directory under `charts/paragon-onprem/charts/<service-name>/` with `Chart.yaml`, `values.yaml`, and `templates/`.
2. Add the subchart as a dependency in `charts/paragon-onprem/Chart.yaml`.
3. Add enable condition in `charts/paragon-onprem/values.yaml` (e.g., `subchart.<service-name>.enabled: true`).
4. Update `locals` in each provider's `paragon/variables.tf` to include the service in the microservices map.
5. If the service is public-facing, add it to the public microservices list.
6. Run `prepare.sh` for each provider and validate.

### Adding a New Terraform Variable

1. Add the variable definition in `variables.tf` of the relevant workspace(s).
2. If it's required (no default), `generate-tfvars.mjs` will auto-generate a placeholder in `vars.auto.tfvars` on next `prepare.sh` run.
3. If it's cross-provider, add it to all three providers' corresponding workspace.
4. Wire the variable through `modules.tf` to the appropriate module.
5. Run `terraform validate` on all affected workspaces.

### Adding a New Infrastructure Module

1. Create a new directory under `<provider>/workspaces/infra/` with `variables.tf`, `outputs.tf`, and resource files.
2. Wire it in `infra/modules.tf` with appropriate dependencies.
3. If the module's outputs are needed by the paragon workspace, add them to `infra/outputs.tf`.
4. Document the new output shape in the infra-output JSON contract.
5. Update paragon's `variables.tf` locals to consume the new outputs.
6. Consider whether the module should be conditional (`count` gated on a feature flag).

### Modifying prepare.sh

Key things to know:
- `sed -i ''` is macOS syntax. On Linux it produces harmless warnings but the `__PARAGON_VERSION__` replacement won't work. If you need Linux compatibility, use `sed -i` (no empty string argument) or detect the OS.
- The script requires `rsync`, `node`, `git`, and `shasum` (or `sha256sum`).
- Chart version hashing ensures Helm detects changes: `find | sort | shasum | cut`.
- The script creates `main.tf` from `main.tf.example` only if `main.tf` doesn't exist (safe for re-runs).
- `vars.auto.tfvars` is generated only if it doesn't exist (won't overwrite operator values).

## Verification Checklist for Pull Requests

Before submitting a PR with Terraform changes:

- [ ] `terraform fmt -check -recursive` passes on all modified directories
- [ ] `terraform validate` passes on all 6 workspaces (`aws/azure/gcp` x `infra/paragon`)
- [ ] If adding variables: check all three providers for consistency
- [ ] If modifying modules: verify module interface (inputs/outputs) is consistent
- [ ] If changing outputs: verify the paragon workspace still correctly reads infra JSON
- [ ] If touching Helm values/charts: run `prepare.sh` for affected providers and `helm lint`
- [ ] If touching scripts: test `prepare.sh` with a real git tag for all providers
- [ ] No hardcoded secrets or credentials
- [ ] Sensitive variables/outputs are marked `sensitive = true`
- [ ] New resources follow `${var.workspace}-*` naming convention
- [ ] Conditional resources use `count` (single) or `for_each` (multiple) appropriately
- [ ] New feature flags use `bool` type with `default = false`
