# Paragon GCP Infrastructure

NOTE: The following APIs must be enabled for the project in the [GCP Console](https://console.developers.google.com/apis/api/compute.googleapis.com/overview).
- Compute Engine API


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.16.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 6.16.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_network"></a> [network](#module\_network) | ./network | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_authorized_networks"></a> [authorized\_networks](#input\_authorized\_networks) | A list of authorized CIDR-formatted IP address ranges that can connect to this DB. Only applies to public IP instances. | `list(map(string))` | `[]` | no |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS` | `string` | `"dummy-cloudflare-tokens-must-be-40-chars"` | no |
| <a name="input_cloudflare_tunnel_account_id"></a> [cloudflare\_tunnel\_account\_id](#input\_cloudflare\_tunnel\_account\_id) | Account ID for Cloudflare account | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_email_domain"></a> [cloudflare\_tunnel\_email\_domain](#input\_cloudflare\_tunnel\_email\_domain) | Email domain for Cloudflare access | `string` | `"useparagon.com"` | no |
| <a name="input_cloudflare_tunnel_enabled"></a> [cloudflare\_tunnel\_enabled](#input\_cloudflare\_tunnel\_enabled) | Flag whether to enable Cloudflare Zero Trust tunnel for bastion | `bool` | `false` | no |
| <a name="input_cloudflare_tunnel_subdomain"></a> [cloudflare\_tunnel\_subdomain](#input\_cloudflare\_tunnel\_subdomain) | Subdomain under the Cloudflare Zone to create the tunnel | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_zone_id"></a> [cloudflare\_tunnel\_zone\_id](#input\_cloudflare\_tunnel\_zone\_id) | Zone ID for Cloudflare domain | `string` | `""` | no |
| <a name="input_disable_deletion_protection"></a> [disable\_deletion\_protection](#input\_disable\_deletion\_protection) | Used to disable deletion protection on database and storage resources. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Type of environment being deployed to. | `string` | `"enterprise"` | no |
| <a name="input_gcp_client_email"></a> [gcp\_client\_email](#input\_gcp\_client\_email) | The client email for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_client_id"></a> [gcp\_client\_id](#input\_gcp\_client\_id) | The client id for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_client_x509_cert_url"></a> [gcp\_client\_x509\_cert\_url](#input\_gcp\_client\_x509\_cert\_url) | The client certificate url for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_credential_json_file"></a> [gcp\_credential\_json\_file](#input\_gcp\_credential\_json\_file) | The path to the GCP credential JSON file. All other `gcp_` variables are ignored if this is provided. | `string` | `null` | no |
| <a name="input_gcp_private_key"></a> [gcp\_private\_key](#input\_gcp\_private\_key) | The private key for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_private_key_id"></a> [gcp\_private\_key\_id](#input\_gcp\_private\_key\_id) | The id of the private key for the service account. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_gcp_project_id"></a> [gcp\_project\_id](#input\_gcp\_project\_id) | The id of the Google Cloud Project. Required if not using `gcp_credential_json_file`. | `string` | `null` | no |
| <a name="input_ip_whitelist"></a> [ip\_whitelist](#input\_ip\_whitelist) | An optional list of IP addresses to whitelist access to for microservices with private acl. | `string` | `""` | no |
| <a name="input_k8s_max_node_count"></a> [k8s\_max\_node\_count](#input\_k8s\_max\_node\_count) | Maximum number of node Kubernetes can scale up to. | `number` | `20` | no |
| <a name="input_k8s_min_node_count"></a> [k8s\_min\_node\_count](#input\_k8s\_min\_node\_count) | Minimum number of node Kubernetes can scale down to. | `number` | `3` | no |
| <a name="input_k8s_ondemand_node_instance_type"></a> [k8s\_ondemand\_node\_instance\_type](#input\_k8s\_ondemand\_node\_instance\_type) | The compute instance type to use for Kubernetes on demand nodes. | `string` | `"e2-standard-2"` | no |
| <a name="input_k8s_spot_instance_percent"></a> [k8s\_spot\_instance\_percent](#input\_k8s\_spot\_instance\_percent) | The percentage of spot instances to use for Kubernetes nodes. | `number` | `75` | no |
| <a name="input_k8s_spot_node_instance_type"></a> [k8s\_spot\_node\_instance\_type](#input\_k8s\_spot\_node\_instance\_type) | The compute instance type to use for Kubernetes spot nodes. | `string` | `"e2-standard-2"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | The version of Kubernetes to run in the cluster. | `string` | `"1.31"` | no |
| <a name="input_organization"></a> [organization](#input\_organization) | Name of organization to include in resource names. | `string` | n/a | yes |
| <a name="input_postgres_multiple_instances"></a> [postgres\_multiple\_instances](#input\_postgres\_multiple\_instances) | Whether or not to create multiple Postgres instances. Used for higher volume installations. | `bool` | `true` | no |
| <a name="input_postgres_tier"></a> [postgres\_tier](#input\_postgres\_tier) | The instance type to use for Postgres. | `string` | `"db-f1-micro"` | no |
| <a name="input_redis_memory_size"></a> [redis\_memory\_size](#input\_redis\_memory\_size) | The size of the Redis instance (in GB). | `number` | `2` | no |
| <a name="input_redis_multiple_instances"></a> [redis\_multiple\_instances](#input\_redis\_multiple\_instances) | Whether or not to create multiple Redis instances. | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | The region where to host Google Cloud Organization resources. | `string` | n/a | yes |
| <a name="input_region_zone"></a> [region\_zone](#input\_region\_zone) | The zone in the region where to host Google Cloud Organization resources. | `string` | n/a | yes |
| <a name="input_region_zone_backup"></a> [region\_zone\_backup](#input\_region\_zone\_backup) | The backup zone in the region where to host Google Cloud Organization resources. | `string` | n/a | yes |
| <a name="input_ssh_whitelist"></a> [ssh\_whitelist](#input\_ssh\_whitelist) | An optional list of IP addresses to whitelist ssh access. | `string` | `""` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR for the virtual network. A `/16` (65,536 IPs) or larger is recommended. | `string` | `"10.0.0.0/16"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

## Updates

This Terraform documentation can be automatically regenerated with:

```
terraform-docs markdown table --output-file README.md --output-mode inject .
```
