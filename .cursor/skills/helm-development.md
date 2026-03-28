# Helm Development Skill

Use this skill when modifying, creating, or debugging Helm charts in this repository, or when working with `prepare.sh`, `scripts/update-charts.mjs`, `service-inputs.json`, or any files under `charts/`.

## Repository Helm Architecture

This repository uses a **parent-chart-with-subcharts** pattern organized into four top-level Helm charts:

| Chart | Type | Purpose |
|-------|------|---------|
| `charts/paragon-onprem` | application | Core Paragon microservices and workers |
| `charts/paragon-monitoring` | application | Monitoring stack (Prometheus, Grafana, exporters) |
| `charts/paragon-logging` | application | Logging stack (Fluent Bit, OpenObserve) |
| `charts/paragon-templates` | **library** | Shared template definitions used by subcharts |

Each application chart declares its subcharts as `file://` dependencies in `Chart.yaml`. The `paragon-templates` library chart is also a dependency of both `paragon-onprem` and `paragon-monitoring`, referenced as `file://../paragon-templates`.

### Subchart-to-Parent-Chart Mapping

- **`paragon-onprem`**: `account`, `api-triggerkit`, `cache-replay`, `cerberus`, `connect`, `dashboard`, `hades`, `health-checker`, `hermes`, `minio`, `passport`, `pheme`, `release`, `zeus`, `worker-actionkit`, `worker-actions`, `worker-auditlogs`, `worker-credentials`, `worker-crons`, `worker-deployments`, `worker-eventlogs`, `worker-proxy`, `worker-triggerkit`, `worker-triggers`, `worker-workflows`, `flipt`
- **`paragon-monitoring`**: `bull-exporter`, `grafana`, `kafka-exporter`, `kube-state-metrics`, `node-exporter`, `pgadmin`, `postgres-exporter`, `prometheus`, `redis-exporter`, `redis-insight`
- **`paragon-logging`**: `fluent-bit`, `openobserve`

### Subchart Enable/Disable

Each subchart can be toggled via `condition` fields in the parent `Chart.yaml`, controlled by values like:
```yaml
subchart:
  zeus:
    enabled: true
  cache-replay:
    enabled: false
```

---

## The `paragon-templates` Library Chart

The library chart at `charts/paragon-templates/` (`type: library` in its `Chart.yaml`) provides reusable named templates that standardize Kubernetes resource definitions across all Paragon services. It is **never installed directly**—it exists only to share template code.

### Available Templates

| Template Name | File | Purpose |
|---------------|------|---------|
| `deployment.standard` | `_deployment.yaml` | Standard Deployment with probes, env, lifecycle hooks |
| `statefulset.standard` | `_stateful-set.yaml` | StatefulSet with PVC templates |
| `service.standard` | `_service.yaml` | ClusterIP Service |
| `ingress.standard` | `_ingress.yaml` | Ingress with AWS ALB / Azure NGINX / GCP annotations |
| `hpa.standard` | `_hpa.yaml` | HorizontalPodAutoscaler |
| `pdb.standard` | `_pdb.yaml` | PodDisruptionBudget (enabled by default) |
| `secret.standard` | `_secret.yaml` | Opaque Secret from `.Values.secrets` |
| `serviceaccount.standard` | `_serviceaccount.yaml` | ServiceAccount |
| `rolebinding.standard` | `_role-binding.yaml` | RoleBinding for HPA modification |
| `migration.standard` | `_migration.yaml` | Pre-install/pre-upgrade Job for DB migrations |
| `env.standard` | `_env.yaml` | Environment variables from `service-inputs.json` + global values |
| `service.inputs` | `_service-inputs.tpl` | Loads `files/service-inputs.json` for the current subchart |

### How Subcharts Use Library Templates

Most Paragon service subcharts are thin wrappers that delegate entirely to library templates. A typical subchart's `templates/` directory looks like:

```
templates/
  _helpers.tpl          # Standard Helm helpers (name, fullname, labels, ingressHost)
  deployment.yaml       # {{- include "deployment.standard" (dict "root" $ "command" "./zeus") }}
  service.yaml          # {{- include "service.standard" $ }}
  ingress.yaml          # {{- include "ingress.standard" $ }}
  hpa.yaml              # {{- include "hpa.standard" $ }}
  pdb.yaml              # {{- include "pdb.standard" . }}
  secret.yaml           # {{- include "secret.standard" $ }}
  serviceaccount.yaml   # {{- include "serviceaccount.standard" $ }}
  role-binding.yaml     # {{- include "rolebinding.standard" $ }}
  migration.yaml        # {{- include "migration.standard" (dict "root" $ "imageName" "postgres-zeus") }}
```

Each template file is typically **one line** that calls the corresponding library template. The `_helpers.tpl` file defines the service-specific named templates (e.g., `zeus.fullname`, `zeus.labels`, `zeus.selectorLabels`, `zeus.ingressHost`) that the library templates reference dynamically via `include (printf "%s.fullname" $name)`.

### Template Parameter Conventions

- `deployment.standard` takes `(dict "root" $ "command" "./service-name")` where `command` is the Docker entrypoint
- `statefulset.standard` takes `(dict "root" $ "volumeName" "name" "mountPath" "/path" "storageSize" "100Gi")`
- `migration.standard` takes `(dict "root" $ "imageName" "postgres-zeus")` where `imageName` is the migration Docker image
- Most other templates take just `$` (the root context)

### Critical: `_helpers.tpl` Naming Convention

Every subchart **must** define its own `_helpers.tpl` with named templates following the pattern `<chart-name>.<helper>`. The library templates dynamically construct template names using `printf "%s.fullname" $name` where `$name` comes from `.Chart.Name`. If these helpers are missing or misnamed, the library templates will fail.

Required helper templates for each subchart:
- `<name>.name`
- `<name>.fullname`
- `<name>.chart`
- `<name>.labels`
- `<name>.selectorLabels`
- `<name>.serviceAccountName`
- `<name>.ingressHost` (if ingress is used)

---

## Do NOT Create New Full Charts for New Services

**New Paragon services should reuse the existing `paragon-templates` library templates** rather than creating entirely new standalone charts. The standard pattern is:

1. Create a new subchart directory under the appropriate parent chart (usually `charts/paragon-onprem/charts/<service-name>/`)
2. Add `Chart.yaml`, `values.yaml`, `.helmignore`
3. Add `templates/_helpers.tpl` with standard helpers using the service name
4. Add one-line template files that call library templates (e.g., `deployment.yaml` → `{{- include "deployment.standard" ... }}`)
5. Register the subchart as a dependency in the parent `Chart.yaml`
6. Add the subchart enable toggle to the parent `values.yaml`
7. Add the service to `service-inputs.json` processing (update the monorepo)

The only exceptions to this pattern are third-party tools (like `flipt`, `kube-state-metrics`, `node-exporter`) which have their own chart structure and don't use the library templates.

### Copying an Existing Subchart as a Starting Point

The fastest way to create a new service subchart:
```bash
cp -r charts/paragon-onprem/charts/zeus charts/paragon-onprem/charts/new-service
```
Then find-and-replace `zeus` with `new-service` across all files in the new directory, update the `command` in `deployment.yaml`, adjust `values.yaml` (ports, resources, replicas), and register it in the parent chart.

---

## `service-inputs.json` — The Service Metadata Pipeline

### Origin and Purpose

The `service-inputs.json` file is **generated by the Paragon monorepo during releases** and committed to this repository as part of versioned git tags. It contains metadata about every Paragon service including its environment variable requirements and secret key requirements.

### Git Tag Format

Tags follow calendar versioning: **`YYYY.MMDD.HHMM-<8-char-git-sha>`**

Examples:
- `2026.0326.1844-30030741`
- `2025.1218.2022-7ffd98b5`

### File Location in Tags

In git tags, the file lives at `charts/files/service-inputs.json`. This path does NOT exist on the working branch—it only exists inside tagged commits created by the CI automation.

### File Structure

```json
{
  "inputs": {
    "services": [
      {
        "name": "zeus",
        "category": "microservice",
        "envKeys": {
          "ZEUS_PORT": "required",
          "HOST_ENV": "required",
          ...
        },
        "secretKeys": {
          "ZEUS_POSTGRES_PASSWORD": "required",
          "LICENSE": "required",
          ...
        }
      },
      ...
    ]
  },
  "platformEnv": "production",
  "version": "2026.0326.1844-30030741"
}
```

Key fields per service:
- **`name`**: Service identifier matching the subchart directory name
- **`category`**: One of `microservice`, `worker`, or `monitor`
- **`envKeys`**: Object mapping environment variable names to `"required"`
- **`secretKeys`**: Object mapping secret variable names to `"required"`

The `version` field at the top level matches the git tag.

### How `service-inputs.json` Is Processed

#### 1. CI Automation (`update-charts.yaml` workflow)

The GitHub Actions workflow `.github/workflows/update-charts.yaml` triggers on `repository_dispatch` events with type `update-charts`. It receives the full service inputs as the client payload, runs `scripts/update-charts.mjs` with that payload, then commits and tags the result via `scripts/push-versioned-commit.sh`.

#### 2. `scripts/update-charts.mjs` — Splitting to Per-Subchart Files

This script reads the monolithic `service-inputs.json` and splits it into per-subchart `files/service-inputs.json` files:

1. Parses the input JSON (containing all services)
2. For each service, determines the parent chart category:
   - Services named `openobserve` or `fluent-bit` → `paragon-logging`
   - Services with category `monitor` → `paragon-monitoring`
   - All others → `paragon-onprem`
3. Flattens `envKeys` and `secretKeys` from objects `{ KEY: "required" }` to sorted arrays `["KEY1", "KEY2", ...]`
4. Writes the per-service JSON to `charts/<parent>/charts/<service>/files/service-inputs.json`
5. Verifies each service has a corresponding subchart directory (fails if missing)

**Ignored services** (defined in `ignoredServices` array in the script): `embassy`, `prometheus-ecs-discovery`, `redis-streams-exporter`, `alb-log-parser`. These services exist in the monorepo but have no corresponding Helm chart.

#### 3. `prepare.sh` — Extracting from Tags

When run locally or in deployment, `prepare.sh`:
1. Fetches git tags, selects the specified or latest tag
2. Archives the tag contents to a temp directory
3. Reads `charts/files/service-inputs.json` from the archive
4. Runs `update-charts.mjs` to distribute per-service JSON files
5. Copies charts to the provider destination (e.g., `aws/workspaces/paragon/charts/`)
6. Computes SHA-256 hashes of chart contents and replaces `__PARAGON_VERSION__` placeholders

#### 4. Template Consumption — `_service-inputs.tpl` and `_env.yaml`

At Helm render time, the per-subchart `files/service-inputs.json` is loaded by the library template:

```gotemplate
{{- define "service.inputs" -}}
{{- $root := .root | default . -}}
{{- $root.Files.Get "files/service-inputs.json" -}}
{{- end -}}
```

This is consumed by:

- **`_env.yaml`** (`env.standard`): Reads `envKeys` and `secretKeys` arrays from the JSON. For each env key, looks up the value in `.Values.env` (service-level) then `.Values.global.env` (global). For each secret key, creates a `secretKeyRef` pointing to the shared or per-service secret.

- **`_deployment.yaml`** (`deployment.standard`): Reads the `category` field to conditionally add lifecycle hooks and health probes (only for `microservice` and `worker` categories).

This pipeline means **services declare their own env/secret requirements in the monorepo**, and the Helm charts automatically pick them up without manual values.yaml edits.

---

## Version Placeholder System (`__PARAGON_VERSION__`)

All `Chart.yaml` files in the source charts use `version: __PARAGON_VERSION__` as a placeholder. This is **intentional** and gets replaced during the `prepare.sh` build step.

### How Versioning Works

1. `prepare.sh` defines a base version (e.g., `version="2026.03.19"`)
2. For each chart directory, it computes an 8-character SHA-256 hash of all files in that chart
3. It replaces `__PARAGON_VERSION__` with `<version>-<hash>` (e.g., `2026.03.19-a1b2c3d4`)
4. The hash ensures chart versions change when chart contents change, enabling proper Helm upgrade detection

### Important: Linux vs macOS `sed`

`prepare.sh` uses `sed -i ''` which is macOS syntax. On Linux, this creates a harmless error and the placeholders won't be replaced. For Linux-only usage, `sed -i` (without the empty string argument) would be needed.

---

## Modifying Helm Charts — Best Practices

### Making Changes to Shared Templates

When editing files in `charts/paragon-templates/templates/`:
- Changes affect **all subcharts** across `paragon-onprem` and `paragon-monitoring`
- Test thoroughly by linting multiple prepared charts
- Use conditional logic (e.g., `{{- if .Values.someFeature }}`) to make changes opt-in when possible
- Named template definitions are globally scoped—namespace them carefully

### Making Changes to a Single Service

1. Edit files in the specific subchart (e.g., `charts/paragon-onprem/charts/zeus/`)
2. Subchart `values.yaml` provides defaults; parent chart values can override them
3. Global values (`.Values.global.*`) are shared across all subcharts

### Values Override Hierarchy

From lowest to highest priority:
1. Subchart `values.yaml` defaults
2. Parent chart `values.yaml` (under the subchart name key)
3. `.secure/values.yaml` or Terraform-provided values (at deploy time)
4. `--set` flags (if using Helm CLI directly)

### Environment Variables and Secrets

- **Do NOT hardcode env var lists** in subchart values files. They come from `service-inputs.json` automatically.
- To add a new env var, it must be added to the service's code in the Paragon monorepo (which generates `service-inputs.json`).
- To add a custom env var for a specific deployment, use the `envKeys` override in `values.yaml`:
  ```yaml
  zeus:
    envKeys:
      - CUSTOM_VAR
  ```
  This merges with the auto-generated list from `service-inputs.json`.

---

## Testing and Validation

### Running `prepare.sh`

```bash
./prepare.sh -p aws -t 2026.0326.1844-30030741
```

This prepares charts for the specified provider and tag. Use `-p k8s` for Helm-only (no Terraform) output to `dist/`.

### Helm Lint (on Prepared Charts)

Always lint **prepared** charts (after `prepare.sh`), not source charts (which have `__PARAGON_VERSION__` placeholders):

```bash
# Lint a specific chart
helm lint aws/workspaces/paragon/charts/paragon-logging

# Lint all prepared charts
for chart in aws/workspaces/paragon/charts/*/; do
  echo "Linting: $chart"
  helm lint "$chart"
done
```

**Expected errors**: `paragon-onprem` and `paragon-monitoring` will show errors about the missing `paragon-templates` dependency. This is normal—the library dependency is resolved during `helm dependency build` at actual deployment time, not during lint.

`paragon-logging` should lint cleanly since it doesn't depend on `paragon-templates`.

### Terraform Validate

For infrastructure changes:
```bash
cd aws/workspaces/paragon && terraform init -backend=false && terraform validate
cd aws/workspaces/infra && terraform init -backend=false && terraform validate
```

### Helm Template (Dry-Run Rendering)

To see rendered YAML without deploying (useful for debugging template logic):
```bash
helm template my-release aws/workspaces/paragon/charts/paragon-logging
```

Note: This won't work for charts that depend on `paragon-templates` unless you first run `helm dependency build`.

### Validation Checklist

Before committing Helm chart changes:

1. **Run `prepare.sh`** for at least one provider to verify version substitution and chart copying
2. **Run `helm lint`** on prepared charts (expect dependency errors for onprem/monitoring)
3. **Run `terraform validate`** if Terraform files were changed
4. **Check `update-charts.mjs`** if adding/removing services—ensure the `ignoredServices` list and `getChartCategory()` mapping are correct
5. **Verify `_helpers.tpl`** naming if creating new subcharts—all helpers must be prefixed with the chart name

---

## Multi-Cloud Ingress

The `ingress.standard` template in `paragon-templates` handles AWS, Azure, GCP, and generic Kubernetes ingress annotations automatically based on the `HOST_ENV` value:

| `HOST_ENV` | Ingress Class | TLS | Load Balancer |
|------------|---------------|-----|---------------|
| `AWS_K8` | ALB | ACM certificate ARN | AWS ALB with SSL redirect |
| `AZURE_K8` | NGINX | cert-manager/Let's Encrypt | Azure LB |
| `GCP_K8` | GCE | Pre-shared cert | GCP static IP |
| Other | NGINX | cert-manager/Let's Encrypt | Default |

When modifying ingress behavior, test with all relevant `HOST_ENV` values.

---

## Key File Paths Reference

| Path | Purpose |
|------|---------|
| `charts/paragon-templates/templates/_*.yaml` | Shared library templates |
| `charts/paragon-templates/templates/_service-inputs.tpl` | Loads per-subchart service-inputs.json |
| `charts/paragon-onprem/Chart.yaml` | Parent chart dependencies list |
| `charts/paragon-onprem/values.yaml` | Default subchart enable/disable and global values |
| `charts/paragon-onprem/charts/<svc>/` | Individual service subcharts |
| `charts/paragon-onprem/charts/<svc>/files/service-inputs.json` | Per-service env/secret metadata (auto-generated) |
| `charts/values.placeholder.yaml` | Template for `.secure/values.yaml` with all configuration |
| `charts/example.yaml` | Deprecated Helm-only deployment values example |
| `scripts/update-charts.mjs` | Splits monolithic service-inputs.json into per-subchart files |
| `scripts/generate-tfvars.mjs` | Generates placeholder `.tfvars` from `variables.tf` |
| `scripts/push-versioned-commit.sh` | CI helper: commits, tags, and force-pushes tags |
| `prepare.sh` | Main entry point: fetches tag, runs update-charts, copies/versions charts |
| `.github/workflows/update-charts.yaml` | CI workflow triggered by monorepo releases |
