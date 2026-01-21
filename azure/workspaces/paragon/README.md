# Paragon Azure Deployment

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.14.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dns"></a> [dns](#module\_dns) | ./dns | n/a |
| <a name="module_helm"></a> [helm](#module\_helm) | ./helm | n/a |
| <a name="module_monitors"></a> [monitors](#module\_monitors) | ./monitors | n/a |
| <a name="module_uptime"></a> [uptime](#module\_uptime) | ./uptime | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_client_id"></a> [azure\_client\_id](#input\_azure\_client\_id) | Azure client ID | `string` | n/a | yes |
| <a name="input_azure_client_secret"></a> [azure\_client\_secret](#input\_azure\_client\_secret) | Azure client secret | `string` | n/a | yes |
| <a name="input_azure_subscription_id"></a> [azure\_subscription\_id](#input\_azure\_subscription\_id) | Azure subscription ID | `string` | n/a | yes |
| <a name="input_azure_tenant_id"></a> [azure\_tenant\_id](#input\_azure\_tenant\_id) | Azure tenant ID | `string` | n/a | yes |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Zone `DNS` | `string` | `null` | no |
| <a name="input_cloudflare_zone_id"></a> [cloudflare\_zone\_id](#input\_cloudflare\_zone\_id) | Cloudflare zone id to set CNAMEs. | `string` | `null` | no |
| <a name="input_docker_email"></a> [docker\_email](#input\_docker\_email) | Docker email to pull images. | `string` | n/a | yes |
| <a name="input_docker_password"></a> [docker\_password](#input\_docker\_password) | Docker password to pull images. | `string` | n/a | yes |
| <a name="input_docker_registry_server"></a> [docker\_registry\_server](#input\_docker\_registry\_server) | Docker container registry server. | `string` | `"docker.io"` | no |
| <a name="input_docker_username"></a> [docker\_username](#input\_docker\_username) | Docker username to pull images. | `string` | n/a | yes |
| <a name="input_domain"></a> [domain](#input\_domain) | The root domain used for the microservices. | `string` | n/a | yes |
| <a name="input_excluded_microservices"></a> [excluded\_microservices](#input\_excluded\_microservices) | The microservices that should be excluded from the deployment. | `list(string)` | `[]` | no |
| <a name="input_feature_flags"></a> [feature\_flags](#input\_feature\_flags) | Optional path to feature flags YAML file. | `string` | `null` | no |
| <a name="input_health_checker_enabled"></a> [health\_checker\_enabled](#input\_health\_checker\_enabled) | Specifies that health checker is enabled. | `bool` | `false` | no |
| <a name="input_helm_yaml"></a> [helm\_yaml](#input\_helm\_yaml) | YAML string of helm values to use instead of `helm_yaml_path` | `string` | `null` | no |
| <a name="input_helm_yaml_path"></a> [helm\_yaml\_path](#input\_helm\_yaml\_path) | Path to helm values.yaml file. | `string` | `".secure/values.yaml"` | no |
| <a name="input_infra_json"></a> [infra\_json](#input\_infra\_json) | JSON string of `infra` workspace variables to use instead of `infra_json_path` | `string` | `null` | no |
| <a name="input_infra_json_path"></a> [infra\_json\_path](#input\_infra\_json\_path) | Path to `infra` workspace output JSON file. | `string` | `".secure/infra-output.json"` | no |
| <a name="input_ingress_scheme"></a> [ingress\_scheme](#input\_ingress\_scheme) | Whether the load balancer is 'internet-facing' (public) or 'internal' (private) | `string` | `"internet-facing"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | The version of Kubernetes to run in the cluster. | `string` | `"1.31"` | no |
| <a name="input_monitor_version"></a> [monitor\_version](#input\_monitor\_version) | The version of the Paragon monitors to install. | `string` | `null` | no |
| <a name="input_monitors_enabled"></a> [monitors\_enabled](#input\_monitors\_enabled) | Specifies that monitors are enabled. | `bool` | `false` | no |
| <a name="input_openobserve_email"></a> [openobserve\_email](#input\_openobserve\_email) | OpenObserve admin login email. | `string` | `null` | no |
| <a name="input_openobserve_password"></a> [openobserve\_password](#input\_openobserve\_password) | OpenObserve admin login password. | `string` | `null` | no |
| <a name="input_organization"></a> [organization](#input\_organization) | Name of organization to include in resource names. | `string` | n/a | yes |
| <a name="input_private_services"></a> [private\_services](#input\_private\_services) | Services that should not be publicly exposed (filtered from public\_microservices and public\_monitors). | `list(string)` | `[]` | no |
| <a name="input_uptime_api_token"></a> [uptime\_api\_token](#input\_uptime\_api\_token) | Optional API Token for setting up BetterStack Uptime monitors. | `string` | `null` | no |
| <a name="input_uptime_company"></a> [uptime\_company](#input\_uptime\_company) | Optional pretty company name to include in BetterStack Uptime monitors. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_grafana_admin_email"></a> [grafana\_admin\_email](#output\_grafana\_admin\_email) | Grafana admin login email. |
| <a name="output_grafana_admin_password"></a> [grafana\_admin\_password](#output\_grafana\_admin\_password) | Grafana admin login password. |
| <a name="output_load_balancer"></a> [load\_balancer](#output\_load\_balancer) | Location of the load balancer |
| <a name="output_pgadmin_admin_email"></a> [pgadmin\_admin\_email](#output\_pgadmin\_admin\_email) | PGAdmin admin login email. |
| <a name="output_pgadmin_admin_password"></a> [pgadmin\_admin\_password](#output\_pgadmin\_admin\_password) | PGAdmin admin login password. |
| <a name="output_uptime_webhook"></a> [uptime\_webhook](#output\_uptime\_webhook) | Uptime webhook URL |
<!-- END_TF_DOCS -->

## Updates

This Terraform documentation can be automatically regenerated with:

```
terraform-docs markdown table --output-file README.md --output-mode inject .
```
