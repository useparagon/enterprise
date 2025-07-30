# Paragon Azure Infrastructure

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 3.0.2 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.14.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bastion"></a> [bastion](#module\_bastion) | ./bastion | n/a |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ./cluster | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./network | n/a |
| <a name="module_postgres"></a> [postgres](#module\_postgres) | ./postgres | n/a |
| <a name="module_redis"></a> [redis](#module\_redis) | ./redis | n/a |
| <a name="module_storage"></a> [storage](#module\_storage) | ./storage | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_client_id"></a> [azure\_client\_id](#input\_azure\_client\_id) | Azure client ID | `string` | n/a | yes |
| <a name="input_azure_client_secret"></a> [azure\_client\_secret](#input\_azure\_client\_secret) | Azure client secret | `string` | n/a | yes |
| <a name="input_azure_subscription_id"></a> [azure\_subscription\_id](#input\_azure\_subscription\_id) | Azure subscription ID | `string` | n/a | yes |
| <a name="input_azure_tenant_id"></a> [azure\_tenant\_id](#input\_azure\_tenant\_id) | Azure tenant ID | `string` | n/a | yes |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS` | `string` | `"dummy-cloudflare-tokens-must-be-40-chars"` | no |
| <a name="input_cloudflare_tunnel_account_id"></a> [cloudflare\_tunnel\_account\_id](#input\_cloudflare\_tunnel\_account\_id) | Account ID for Cloudflare account | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_email_domain"></a> [cloudflare\_tunnel\_email\_domain](#input\_cloudflare\_tunnel\_email\_domain) | Email domain for Cloudflare access | `string` | `"useparagon.com"` | no |
| <a name="input_cloudflare_tunnel_enabled"></a> [cloudflare\_tunnel\_enabled](#input\_cloudflare\_tunnel\_enabled) | Flag whether to enable Cloudflare Zero Trust tunnel for bastion | `bool` | `false` | no |
| <a name="input_cloudflare_tunnel_subdomain"></a> [cloudflare\_tunnel\_subdomain](#input\_cloudflare\_tunnel\_subdomain) | Subdomain under the Cloudflare Zone to create the tunnel | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_zone_id"></a> [cloudflare\_tunnel\_zone\_id](#input\_cloudflare\_tunnel\_zone\_id) | Zone ID for Cloudflare domain | `string` | `""` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Type of environment being deployed to. | `string` | `"enterprise"` | no |
| <a name="input_k8s_max_node_count"></a> [k8s\_max\_node\_count](#input\_k8s\_max\_node\_count) | Maximum number of node Kubernetes can scale up to. | `number` | `20` | no |
| <a name="input_k8s_min_node_count"></a> [k8s\_min\_node\_count](#input\_k8s\_min\_node\_count) | Minimum number of node Kubernetes can scale down to. | `number` | `3` | no |
| <a name="input_k8s_ondemand_node_instance_type"></a> [k8s\_ondemand\_node\_instance\_type](#input\_k8s\_ondemand\_node\_instance\_type) | The compute instance type to use for Kubernetes on demand nodes. | `string` | `"Standard_B2ms"` | no |
| <a name="input_k8s_sku_tier"></a> [k8s\_sku\_tier](#input\_k8s\_sku\_tier) | The SKU Tier of the AKS cluster (`Free`, `Standard` or `Premium`). | `string` | `"Premium"` | no |
| <a name="input_k8s_spot_instance_percent"></a> [k8s\_spot\_instance\_percent](#input\_k8s\_spot\_instance\_percent) | The percentage of spot instances to use for Kubernetes nodes. | `number` | `75` | no |
| <a name="input_k8s_spot_node_instance_type"></a> [k8s\_spot\_node\_instance\_type](#input\_k8s\_spot\_node\_instance\_type) | The compute instance type to use for Kubernetes spot nodes. | `string` | `"Standard_B2ms"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | The version of Kubernetes to run in the cluster. | `string` | `"1.31"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure geographic region to deploy resources in. | `string` | n/a | yes |
| <a name="input_organization"></a> [organization](#input\_organization) | Name of organization to include in resource names. | `string` | n/a | yes |
| <a name="input_postgres_base_sku_name"></a> [postgres\_base\_sku\_name](#input\_postgres\_base\_sku\_name) | Default PostgreSQL SKU name for instances that don't use the main postgres\_sku\_name (e.g. `B_Standard_B2s` or `GP_Standard_D2ds_v5`) | `string` | `"B_Standard_B2s"` | no |
| <a name="input_postgres_multiple_instances"></a> [postgres\_multiple\_instances](#input\_postgres\_multiple\_instances) | Whether or not to create multiple Postgres instances. Used for higher volume installations. | `bool` | `true` | no |
| <a name="input_postgres_redundant"></a> [postgres\_redundant](#input\_postgres\_redundant) | Whether zone redundant HA should be enabled | `bool` | `false` | no |
| <a name="input_postgres_sku_name"></a> [postgres\_sku\_name](#input\_postgres\_sku\_name) | PostgreSQL SKU name (e.g. `B_Standard_B2s` or `GP_Standard_D2ds_v5`) | `string` | `"GP_Standard_D2ds_v5"` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL version (14, 15 or 16) | `string` | `"14"` | no |
| <a name="input_redis_base_capacity"></a> [redis\_base\_capacity](#input\_redis\_base\_capacity) | Default capacity of the Redis cache for instances that don't use the main redis\_capacity. | `number` | `1` | no |
| <a name="input_redis_base_sku_name"></a> [redis\_base\_sku\_name](#input\_redis\_base\_sku\_name) | Default SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`) for instances that don't use the main redis\_sku\_name. | `string` | `"Standard"` | no |
| <a name="input_redis_capacity"></a> [redis\_capacity](#input\_redis\_capacity) | Used to configure the capacity of the Redis cache. | `number` | `1` | no |
| <a name="input_redis_multiple_instances"></a> [redis\_multiple\_instances](#input\_redis\_multiple\_instances) | Whether or not to create multiple Redis instances. | `bool` | `true` | no |
| <a name="input_redis_sku_name"></a> [redis\_sku\_name](#input\_redis\_sku\_name) | The SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`). | `string` | `"Premium"` | no |
| <a name="input_redis_ssl_only"></a> [redis\_ssl\_only](#input\_redis\_ssl\_only) | Flag whether only SSL connections are allowed. | `bool` | `false` | no |
| <a name="input_ssh_whitelist"></a> [ssh\_whitelist](#input\_ssh\_whitelist) | An optional list of IP addresses to whitelist SSH access. | `string` | `""` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR for the virtual network. A `/16` (65,536 IPs) or larger is recommended. | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion"></a> [bastion](#output\_bastion) | Bastion server connection info. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the AKS cluster. |
| <a name="output_logs_container"></a> [logs\_container](#output\_logs\_container) | The bucket used to store system logs. |
| <a name="output_minio"></a> [minio](#output\_minio) | MinIO server connection info. |
| <a name="output_postgres"></a> [postgres](#output\_postgres) | Connection info for Postgres. |
| <a name="output_redis"></a> [redis](#output\_redis) | Connection information for Redis. |
| <a name="output_resource_group"></a> [resource\_group](#output\_resource\_group) | Resource Group that infrastructure was deployed to. |
| <a name="output_workspace"></a> [workspace](#output\_workspace) | The resource group that all resources are associated with. |
<!-- END_TF_DOCS -->

## Updates

This Terraform documentation can be automatically regenerated with:

```
terraform-docs markdown table --output-file README.md --output-mode inject .
```
