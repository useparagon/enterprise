output "connection" {
  value = {
    bastion_dns = local.tunnel_domain
    private_key = tls_private_key.bastion.private_key_pem
  }
  sensitive = true
}

# Connect via IAP (like AWS Session Manager): no open SSH port, works from anywhere.
# 1) Grant yourself: gcloud projects add-iam-policy-binding PROJECT_ID --member='user:YOU@email.com' --role='roles/iap.tunnelResourceAccessor'
# 2) List instance: gcloud compute instances list --filter="name~^${local.bastion_name}" --project=PROJECT_ID
# 3) Tunnel: gcloud compute start-iap-tunnel INSTANCE_NAME 22 --local-host-port=localhost:2222 --zone=ZONE --project=PROJECT_ID
# 4) SSH: ssh -i /path/to/key -p 2222 ubuntu@localhost
# 5) On bastion: gcloud container clusters get-credentials CLUSTER --region REGION --project PROJECT_ID && kubectl get nodes
output "iap_connection_note" {
  value = var.enable_iap ? "IAP SSH enabled. Use: gcloud compute start-iap-tunnel <instance> 22 --local-host-port=localhost:2222 --zone=${var.region_zone} --project=${var.gcp_project_id}" : "IAP disabled."
}
