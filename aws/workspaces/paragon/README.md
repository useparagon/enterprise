<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.70 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.70.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb"></a> [alb](#module\_alb) | ./alb | n/a |
| <a name="module_helm"></a> [helm](#module\_helm) | ./helm | n/a |
| <a name="module_hoop"></a> [hoop](#module\_hoop) | ./hoop | n/a |
| <a name="module_managed_sync_config"></a> [managed\_sync\_config](#module\_managed\_sync\_config) | ./helm-config | n/a |
| <a name="module_monitors"></a> [monitors](#module\_monitors) | ./monitors | n/a |
| <a name="module_uptime"></a> [uptime](#module\_uptime) | ./uptime | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_access_key_id"></a> [aws\_access\_key\_id](#input\_aws\_access\_key\_id) | AWS Access Key for AWS account to provision resources on. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region resources are created in. | `string` | n/a | yes |
| <a name="input_aws_secret_access_key"></a> [aws\_secret\_access\_key](#input\_aws\_secret\_access\_key) | AWS Secret Access Key for AWS account to provision resources on. | `string` | n/a | yes |
| <a name="input_aws_session_token"></a> [aws\_session\_token](#input\_aws\_session\_token) | AWS session token. | `string` | `null` | no |
| <a name="input_certificate"></a> [certificate](#input\_certificate) | Optional ACM certificate ARN of an existing certificate to use with the load balancer. | `string` | `null` | no |
| <a name="input_cloudflare_dns_api_token"></a> [cloudflare\_dns\_api\_token](#input\_cloudflare\_dns\_api\_token) | Cloudflare DNS API token for SSL certificate creation and verification. | `string` | `null` | no |
| <a name="input_cloudflare_zone_id"></a> [cloudflare\_zone\_id](#input\_cloudflare\_zone\_id) | Cloudflare zone id to set CNAMEs. | `string` | `null` | no |
| <a name="input_customer_facing"></a> [customer\_facing](#input\_customer\_facing) | Whether the connections are customer-facing (true limits access to dev-team-oncall/dev-team-managers/admin, false adds dev-team-engineering). | `bool` | `true` | no |
| <a name="input_dns_provider"></a> [dns\_provider](#input\_dns\_provider) | DNS provider to use. | `string` | `"none"` | no |
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
| <a name="input_hoop_agent_id"></a> [hoop\_agent\_id](#input\_hoop\_agent\_id) | Hoop agent ID for connections. Only used if hoop\_enabled is true. | `string` | `null` | no |
| <a name="input_hoop_all_access_groups"></a> [hoop\_all\_access\_groups](#input\_hoop\_all\_access\_groups) | Additional access-control groups allowed when customer\_facing is false. | `list(string)` | <pre>[<br/>  "dev-team-engineering"<br/>]</pre> | no |
| <a name="input_hoop_api_key"></a> [hoop\_api\_key](#input\_hoop\_api\_key) | Hoop API key. Only used if hoop\_enabled is true. | `string` | `null` | no |
| <a name="input_hoop_custom_connections"></a> [hoop\_custom\_connections](#input\_hoop\_custom\_connections) | Custom Hoop connections defined via tfvars. Map of connection names to their configuration. | <pre>map(object({<br/>    type                  = string<br/>    subtype               = optional(string)<br/>    access_mode_runbooks  = optional(string, "enabled")<br/>    access_mode_exec      = optional(string, "enabled")<br/>    access_mode_connect   = optional(string, "disabled")<br/>    access_schema         = optional(string, "disabled")<br/>    command               = optional(list(string))<br/>    secrets               = map(string)<br/>    tags                  = optional(map(string), {})<br/>    guardrail_rules       = optional(list(string), [])<br/>    reviewers             = optional(list(string), [])<br/>    access_control_groups = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_hoop_enabled"></a> [hoop\_enabled](#input\_hoop\_enabled) | Whether to enable Hoop agent. hoop\_key, hoop\_api\_key, and hoop\_agent\_id must be set if this is true. | `bool` | `true` | no |
| <a name="input_hoop_k8s_connections"></a> [hoop\_k8s\_connections](#input\_hoop\_k8s\_connections) | Kubernetes Hoop connections defined via tfvars. Map of connection names to their configuration. If empty, a default k8s-admin connection will be created. | <pre>map(object({<br/>    type                  = optional(string, "custom")<br/>    subtype               = optional(string)<br/>    access_mode_runbooks  = optional(string, "enabled")<br/>    access_mode_exec      = optional(string, "enabled")<br/>    access_mode_connect   = optional(string, "enabled")<br/>    access_schema         = optional(string, "disabled")<br/>    command               = optional(list(string), ["bash"])<br/>    remote_url            = optional(string, "https://kubernetes.default.svc.cluster.local")<br/>    insecure              = optional(string, "true")<br/>    namespace             = optional(string, "paragon")<br/>    secrets               = optional(map(string), {})<br/>    tags                  = optional(map(string), {})<br/>    guardrail_rules       = optional(list(string), [])<br/>    reviewers             = optional(list(string), [])<br/>    access_control_groups = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_hoop_key"></a> [hoop\_key](#input\_hoop\_key) | Hoop agent key (token). Only used if hoop\_enabled is true. | `string` | `null` | no |
| <a name="input_hoop_restricted_access_groups"></a> [hoop\_restricted\_access\_groups](#input\_hoop\_restricted\_access\_groups) | Base access-control groups allowed for all connections. | `list(string)` | <pre>[<br/>  "dev-team-oncall",<br/>  "dev-team-managers",<br/>  "admin"<br/>]</pre> | no |
| <a name="input_hoop_reviewers_access_groups"></a> [hoop\_reviewers\_access\_groups](#input\_hoop\_reviewers\_access\_groups) | Reviewer groups required for customer-facing app connections. | `list(string)` | <pre>[<br/>  "dev-team-managers",<br/>  "admin"<br/>]</pre> | no |
| <a name="input_hoop_slack_app_token"></a> [hoop\_slack\_app\_token](#input\_hoop\_slack\_app\_token) | Slack app token for the Hoop Slack plugin. | `string` | `null` | no |
| <a name="input_hoop_slack_bot_token"></a> [hoop\_slack\_bot\_token](#input\_hoop\_slack\_bot\_token) | Slack bot token for the Hoop Slack plugin. | `string` | `null` | no |
| <a name="input_hoop_slack_channel_ids"></a> [hoop\_slack\_channel\_ids](#input\_hoop\_slack\_channel\_ids) | Slack channel IDs to notify for connections that require reviews. | `list(string)` | `[]` | no |
| <a name="input_infra_json"></a> [infra\_json](#input\_infra\_json) | JSON string of `infra` workspace variables to use instead of `infra_json_path` | `string` | `null` | no |
| <a name="input_infra_json_path"></a> [infra\_json\_path](#input\_infra\_json\_path) | Path to `infra` workspace output JSON file. | `string` | `".secure/infra-output.json"` | no |
| <a name="input_ingress_scheme"></a> [ingress\_scheme](#input\_ingress\_scheme) | Whether the load balancer is 'internet-facing' (public) or 'internal' (private) | `string` | `"internet-facing"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | The version of Kubernetes to run in the cluster. | `string` | `"1.31"` | no |
| <a name="input_managed_sync_enabled"></a> [managed\_sync\_enabled](#input\_managed\_sync\_enabled) | Whether to enable managed sync. | `bool` | `false` | no |
| <a name="input_managed_sync_version"></a> [managed\_sync\_version](#input\_managed\_sync\_version) | The version of the Managed Sync helm chart to install. | `string` | `"latest"` | no |
| <a name="input_monitor_version"></a> [monitor\_version](#input\_monitor\_version) | The version of the Paragon monitors to install. | `string` | `null` | no |
| <a name="input_monitors_enabled"></a> [monitors\_enabled](#input\_monitors\_enabled) | Specifies that monitors are enabled. | `bool` | `false` | no |
| <a name="input_openobserve_email"></a> [openobserve\_email](#input\_openobserve\_email) | OpenObserve admin login email. | `string` | `null` | no |
| <a name="input_openobserve_password"></a> [openobserve\_password](#input\_openobserve\_password) | OpenObserve admin login password. | `string` | `null` | no |
| <a name="input_organization"></a> [organization](#input\_organization) | The name of the organization that's deploying Paragon. | `string` | n/a | yes |
| <a name="input_private_services"></a> [private\_services](#input\_private\_services) | Services that should not be publicly exposed (filtered from public\_microservices and public\_monitors). | `list(string)` | `[]` | no |
| <a name="input_uptime_api_token"></a> [uptime\_api\_token](#input\_uptime\_api\_token) | Optional API Token for setting up BetterStack Uptime monitors. | `string` | `null` | no |
| <a name="input_uptime_company"></a> [uptime\_company](#input\_uptime\_company) | Optional pretty company name to include in BetterStack Uptime monitors. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | The ARN of the application load balancer. |
| <a name="output_grafana_admin_email"></a> [grafana\_admin\_email](#output\_grafana\_admin\_email) | Grafana admin login email. |
| <a name="output_grafana_admin_password"></a> [grafana\_admin\_password](#output\_grafana\_admin\_password) | Grafana admin login password. |
| <a name="output_nameservers"></a> [nameservers](#output\_nameservers) | The nameservers for the Route53 zone. |
| <a name="output_openobserve_email"></a> [openobserve\_email](#output\_openobserve\_email) | n/a |
| <a name="output_openobserve_password"></a> [openobserve\_password](#output\_openobserve\_password) | n/a |
| <a name="output_pgadmin_admin_email"></a> [pgadmin\_admin\_email](#output\_pgadmin\_admin\_email) | PGAdmin admin login email. |
| <a name="output_pgadmin_admin_password"></a> [pgadmin\_admin\_password](#output\_pgadmin\_admin\_password) | PGAdmin admin login password. |
| <a name="output_uptime_webhook"></a> [uptime\_webhook](#output\_uptime\_webhook) | Uptime webhook URL |
<!-- END_TF_DOCS -->

## Updates

This Terraform documentation can be automatically regenerated with:

```
terraform-docs markdown table --output-file README.md --output-mode inject .
```
