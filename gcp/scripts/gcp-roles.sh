#!/bin/bash

# Project-level IAM for the Terraform / automation service account that provisions and
# operates Paragon enterprise GCP infra (GKE, Cloud SQL, Memorystore, GCS, GMK, IAM, etc.).
#
# Diagnostic additions vs a minimal set for provisioning:
# - roles/cloudtrace.user — read Cloud Trace (console + API)
# - roles/logging.viewer — read Cloud Logging for troubleshooting (logWriter is write-only)
# - roles/managedkafka.admin — Google Managed Kafka (managed sync)
# - roles/servicenetworking.networksAdmin — private service connection / VPC peering (Cloud SQL)
# - roles/serviceusage.serviceUsageAdmin — enable/disable APIs (required for Terraform apply)
# - roles/serviceusage.serviceUsageViewer — list enabled APIs / quota visibility for support

PROJECT_ID="your-gcp-project-id"
SERVICE_ACCOUNT="your-service-account@something.iam.gserviceaccount.com"

ROLES=(
  "roles/cloudsql.admin"
  "roles/cloudtrace.user"
  "roles/compute.admin"
  "roles/container.admin"
  "roles/dns.admin"
  "roles/iam.serviceAccountAdmin"
  "roles/iam.serviceAccountKeyAdmin"
  "roles/iam.serviceAccountUser"
  "roles/logging.logWriter"
  "roles/logging.viewer"
  "roles/managedkafka.admin"
  "roles/monitoring.metricWriter"
  "roles/monitoring.viewer"
  "roles/redis.admin"
  "roles/resourcemanager.projectIamAdmin"
  "roles/servicenetworking.networksAdmin"
  "roles/serviceusage.serviceUsageAdmin"
  "roles/serviceusage.serviceUsageViewer"
  "roles/stackdriver.resourceMetadata.writer"
  "roles/storage.admin"
)

for ROLE in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="$ROLE"
done
