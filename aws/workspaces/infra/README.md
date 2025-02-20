# Paragon AWS Infrastructure

See [setup-policy.json](../../setup-policy.json) for permissions that are required to execute this. Note that `<AWS_ACCOUNT_ID>` must be replaced to match target account.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.70 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.72.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bastion"></a> [bastion](#module\_bastion) | ./bastion | n/a |
| <a name="module_cloudtrail"></a> [cloudtrail](#module\_cloudtrail) | ./cloudtrail | n/a |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ./cluster | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./network | n/a |
| <a name="module_postgres"></a> [postgres](#module\_postgres) | ./postgres | n/a |
| <a name="module_redis"></a> [redis](#module\_redis) | ./redis | n/a |
| <a name="module_storage"></a> [storage](#module\_storage) | ./storage | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_bucket_expiration"></a> [app\_bucket\_expiration](#input\_app\_bucket\_expiration) | The number of days to retain S3 app data before deleting | `number` | `365` | no |
| <a name="input_aws_access_key_id"></a> [aws\_access\_key\_id](#input\_aws\_access\_key\_id) | AWS Access Key for AWS account to provision resources on. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region resources are created in. | `string` | n/a | yes |
| <a name="input_aws_secret_access_key"></a> [aws\_secret\_access\_key](#input\_aws\_secret\_access\_key) | AWS Secret Access Key for AWS account to provision resources on. | `string` | n/a | yes |
| <a name="input_aws_session_token"></a> [aws\_session\_token](#input\_aws\_session\_token) | AWS session token. | `string` | `null` | no |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of AZs to cover in a given region. | `number` | `2` | no |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS` | `string` | `"dummy-cloudflare-tokens-must-be-40-chars"` | no |
| <a name="input_cloudflare_tunnel_account_id"></a> [cloudflare\_tunnel\_account\_id](#input\_cloudflare\_tunnel\_account\_id) | Account ID for Cloudflare account | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_email_domain"></a> [cloudflare\_tunnel\_email\_domain](#input\_cloudflare\_tunnel\_email\_domain) | Email domain for Cloudflare access | `string` | `"useparagon.com"` | no |
| <a name="input_cloudflare_tunnel_enabled"></a> [cloudflare\_tunnel\_enabled](#input\_cloudflare\_tunnel\_enabled) | Flag whether to enable Cloudflare Zero Trust tunnel for bastion | `bool` | `false` | no |
| <a name="input_cloudflare_tunnel_subdomain"></a> [cloudflare\_tunnel\_subdomain](#input\_cloudflare\_tunnel\_subdomain) | Subdomain under the Cloudflare Zone to create the tunnel | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_zone_id"></a> [cloudflare\_tunnel\_zone\_id](#input\_cloudflare\_tunnel\_zone\_id) | Zone ID for Cloudflare domain | `string` | `""` | no |
| <a name="input_disable_cloudtrail"></a> [disable\_cloudtrail](#input\_disable\_cloudtrail) | Used to specify that Cloudtrail is disabled. | `bool` | `true` | no |
| <a name="input_disable_deletion_protection"></a> [disable\_deletion\_protection](#input\_disable\_deletion\_protection) | Used to disable deletion protection on RDS and S3 resources. | `bool` | `false` | no |
| <a name="input_eks_admin_arns"></a> [eks\_admin\_arns](#input\_eks\_admin\_arns) | Array of ARNs for IAM users or roles that should have admin access to cluster. Used for viewing cluster resources in AWS dashboard. | `list(string)` | `[]` | no |
| <a name="input_eks_max_node_count"></a> [eks\_max\_node\_count](#input\_eks\_max\_node\_count) | The maximum number of nodes to run in the Kubernetes cluster. | `number` | `30` | no |
| <a name="input_eks_min_node_count"></a> [eks\_min\_node\_count](#input\_eks\_min\_node\_count) | The minimum number of nodes to run in the Kubernetes cluster. | `number` | `4` | no |
| <a name="input_eks_ondemand_node_instance_type"></a> [eks\_ondemand\_node\_instance\_type](#input\_eks\_ondemand\_node\_instance\_type) | The compute instance type to use for Kubernetes nodes. | `string` | `"t3a.large,t3.large"` | no |
| <a name="input_eks_spot_instance_percent"></a> [eks\_spot\_instance\_percent](#input\_eks\_spot\_instance\_percent) | The percentage of spot instances to use for Kubernetes nodes. | `number` | `75` | no |
| <a name="input_eks_spot_node_instance_type"></a> [eks\_spot\_node\_instance\_type](#input\_eks\_spot\_node\_instance\_type) | The compute instance type to use for Kubernetes spot nodes. | `string` | `"t3a.large,t3.large"` | no |
| <a name="input_elasticache_multi_az"></a> [elasticache\_multi\_az](#input\_elasticache\_multi\_az) | Whether or not to enable multi-AZ in each ElastiCache instance. | `bool` | `true` | no |
| <a name="input_elasticache_multiple_instances"></a> [elasticache\_multiple\_instances](#input\_elasticache\_multiple\_instances) | Whether or not to create multiple ElastiCache instances. Used for higher volume installations. | `bool` | `true` | no |
| <a name="input_elasticache_node_type"></a> [elasticache\_node\_type](#input\_elasticache\_node\_type) | The ElastiCache node type used for Redis. | `string` | `"cache.r6g.large"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | The version of Kubernetes to run in the cluster. | `string` | `"1.31"` | no |
| <a name="input_master_guardduty_account_id"></a> [master\_guardduty\_account\_id](#input\_master\_guardduty\_account\_id) | Optional AWS account id to delegate GuardDuty control to. | `string` | `null` | no |
| <a name="input_mfa_enabled"></a> [mfa\_enabled](#input\_mfa\_enabled) | Whether to require MFA for certain configurations (e.g. cloudtrail s3 bucket deletion) | `bool` | `false` | no |
| <a name="input_organization"></a> [organization](#input\_organization) | Name of organization to include in resource names. | `string` | n/a | yes |
| <a name="input_rds_instance_class"></a> [rds\_instance\_class](#input\_rds\_instance\_class) | The RDS instance class type used for Postgres. | `string` | `"db.t4g.small"` | no |
| <a name="input_rds_multi_az"></a> [rds\_multi\_az](#input\_rds\_multi\_az) | Whether or not to enable multi-AZ in each RDS instance. | `bool` | `true` | no |
| <a name="input_rds_multiple_instances"></a> [rds\_multiple\_instances](#input\_rds\_multiple\_instances) | Whether or not to create multiple Postgres instances. Used for higher volume installations. | `bool` | `true` | no |
| <a name="input_rds_postgres_version"></a> [rds\_postgres\_version](#input\_rds\_postgres\_version) | Postgres version for the database. | `string` | `"14"` | no |
| <a name="input_ssh_whitelist"></a> [ssh\_whitelist](#input\_ssh\_whitelist) | An optional list of IP addresses to whitelist ssh access. | `string` | `""` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR for the VPC. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_cidr_newbits"></a> [vpc\_cidr\_newbits](#input\_vpc\_cidr\_newbits) | Newbits used for calculating subnets. | `number` | `3` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion"></a> [bastion](#output\_bastion) | Bastion server connection info. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster. |
| <a name="output_logs_bucket"></a> [logs\_bucket](#output\_logs\_bucket) | The bucket used to store system logs. |
| <a name="output_minio"></a> [minio](#output\_minio) | MinIO server connection info. |
| <a name="output_postgres"></a> [postgres](#output\_postgres) | Connection info for Postgres. |
| <a name="output_redis"></a> [redis](#output\_redis) | Connection information for Redis. |
| <a name="output_workspace"></a> [workspace](#output\_workspace) | The resource group that all resources are associated with. |
<!-- END_TF_DOCS -->

## Updates

This Terraform documentation can be automatically regenerated with:

```
terraform-docs markdown table --output-file README.md --output-mode inject .
```
