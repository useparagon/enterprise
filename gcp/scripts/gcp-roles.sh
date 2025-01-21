#!/bin/bash

# Script to assign roles to a service account within a GCP project using `gcloud`.

# Define the project ID and service account email
PROJECT_ID="your-gcp-project-id"
SERVICE_ACCOUNT="your-service-account@something.iam.gserviceaccount.com"

# List of roles to assign
ROLES=(
   "roles/cloudsql.admin"
   "roles/compute.admin"
   "roles/container.admin"
   "roles/container.clusterAdmin"
   "roles/container.developer"
   "roles/dns.admin"
   "roles/iam.serviceAccountAdmin"
   "roles/iam.serviceAccountKeyAdmin"
   "roles/iam.serviceAccountUser"
   "roles/logging.logWriter"
   "roles/monitoring.metricWriter"
   "roles/monitoring.viewer"
   "roles/redis.admin"
   "roles/resourcemanager.projectIamAdmin"
   "roles/stackdriver.resourceMetadata.writer"
   "roles/storage.admin"
)

# Loop through each role and assign it to the service account
for ROLE in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="$ROLE"
done
