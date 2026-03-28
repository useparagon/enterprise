# Agents

## Cursor Cloud specific instructions

### Overview

This is a **Paragon Enterprise** self-hosted deployment repository — an infrastructure-as-code (IaC) toolkit for deploying Paragon microservices to Kubernetes on AWS, Azure, or GCP. It contains **no application source code**; only Helm charts, Terraform configs, and Node.js helper scripts.

### Repository layout

- `charts/` — Cloud-agnostic Helm charts (`paragon-onprem`, `paragon-monitoring`, `paragon-logging`, `paragon-templates`)
- `aws/`, `azure/`, `gcp/` — Cloud-specific Terraform workspaces (`infra` and `paragon` each)
- `scripts/` — Node.js ESM helpers (`update-charts.mjs`, `generate-tfvars.mjs`) with pnpm for dev deps
- `prepare.sh` — Main entry-point: copies charts, generates tfvars, hashes chart versions

### Required tools

| Tool | Purpose |
|------|---------|
| Node.js (v22+) | Runs helper scripts in `scripts/` |
| pnpm | Installs dev dependencies in `scripts/` |
| Terraform (~1.9) | Validates and applies IaC configs |
| Helm (v3) | Lints and packages Kubernetes charts |
| rsync | Used by `prepare.sh` to copy chart files |

### Key development commands

- **Install script deps**: `cd scripts && pnpm install`
- **Prepare charts** (hello-world for this repo): `./prepare.sh -p <aws|azure|gcp> -t <GIT_TAG>`
- **Terraform validate** (per workspace): `cd <provider>/workspaces/<infra|paragon> && terraform init -backend=false && terraform validate`
- **Helm lint** (on prepared charts): `helm lint <provider>/workspaces/paragon/charts/paragon-logging`
- **Generate tfvars**: `node scripts/generate-tfvars.mjs <variables.tf> <output.tfvars>`

### Gotchas

- `prepare.sh` uses `sed -i ''` (macOS syntax). On Linux this produces harmless `sed: can't read : No such file or directory` warnings — the `__PARAGON_VERSION__` placeholders in prepared charts won't be replaced, but the rest of the script works fine. If you need the version replacement to work on Linux, use `sed -i` (no empty string argument).
- The source Helm charts in `charts/` contain `__PARAGON_VERSION__` placeholders and will fail `helm lint`. Always lint the **prepared** charts under `<provider>/workspaces/paragon/charts/` after running `prepare.sh`.
- Helm lint on `paragon-onprem` and `paragon-monitoring` will show errors about missing `paragon-templates` dependency — this is expected since the library chart dependency is resolved by `helm dependency build` during Terraform-driven deployment.
- `terraform init -backend=false` is required for local validation since backend configs reference remote state stores.
- Files under `.secure/`, `main.tf`, and `*.tfvars` are gitignored. `prepare.sh` generates them from templates/examples.
- There are no automated tests or lint scripts in this repo. Validation = `terraform validate` + `helm lint` + running `prepare.sh`.
