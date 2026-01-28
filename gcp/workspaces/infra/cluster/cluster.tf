# Get the current service account that Terraform is running under
data "google_client_openid_userinfo" "me" {}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "41.0.0"

  # Using different name to allow cluster replacement when toggling public/private endpoint
  # WARNING: This is destructive and will delete the existing cluster!
  name = var.disable_public_endpoint ? "${var.workspace}-private" : "${var.workspace}-cluster"

  create_service_account     = true
  default_max_pods_per_node  = 20
  deletion_protection        = !var.disable_deletion_protection
  filestore_csi_driver       = false
  horizontal_pod_autoscaling = true
  http_load_balancing        = true
  ip_range_pods              = "ip-pods-secondary-range"
  ip_range_services          = "ip-services-secondary-range"
  kubernetes_version         = var.k8s_version
  network                    = var.network.name
  network_policy             = false
  project_id                 = var.gcp_project_id
  region                     = var.region
  remove_default_node_pool   = true
  subnetwork                 = var.private_subnet.name
  zones                      = [var.region_zone, var.region_zone_backup]

  # Private cluster configuration
  # Note: these are immutable and will trigger a cluster replacement if changed
  enable_private_endpoint         = var.disable_public_endpoint
  enable_private_nodes            = var.disable_public_endpoint
  gcp_public_cidrs_access_enabled = !var.disable_public_endpoint

  node_pools = flatten([
    var.k8s_spot_instance_percent < 100 ? [
      {
        name                 = "ondemand-node-pool"
        auto_repair          = true
        auto_upgrade         = true
        disk_size_gb         = 100
        disk_type            = "pd-standard"
        enable_gcfs          = false
        enable_gvnic         = false
        enable_private_nodes = true
        image_type           = "COS_CONTAINERD"
        initial_node_count   = ceil(var.k8s_min_node_count * (1 - (var.k8s_spot_instance_percent / 100)))
        local_ssd_count      = 0
        machine_type         = var.k8s_ondemand_node_instance_type
        max_count            = ceil(var.k8s_max_node_count * (1 - (var.k8s_spot_instance_percent / 100)))
        min_count            = ceil(var.k8s_min_node_count * (1 - (var.k8s_spot_instance_percent / 100)))
        node_locations       = "${var.region_zone},${var.region_zone_backup}"
        preemptible          = false
        spot                 = false
    }] : [],

    var.k8s_spot_instance_percent > 0 ? [
      {
        name                 = "spot-node-pool"
        auto_repair          = true
        auto_upgrade         = true
        disk_size_gb         = 100
        disk_type            = "pd-standard"
        enable_gcfs          = false
        enable_gvnic         = false
        enable_private_nodes = true
        image_type           = "COS_CONTAINERD"
        initial_node_count   = ceil(var.k8s_min_node_count * (var.k8s_spot_instance_percent / 100))
        local_ssd_count      = 0
        machine_type         = var.k8s_spot_node_instance_type
        max_count            = ceil(var.k8s_max_node_count * (var.k8s_spot_instance_percent / 100))
        min_count            = ceil(var.k8s_min_node_count * (var.k8s_spot_instance_percent / 100))
        node_locations       = "${var.region_zone},${var.region_zone_backup}"
        preemptible          = false
        spot                 = true
    }] : [],
  ])

  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  node_pools_labels = {
    all = {}
    ondemand-node-pool = {
      "useparagon.com/capacityType" = "ondemand"
    }
    spot-node-pool = {
      "useparagon.com/capacityType" = "spot"
    }
  }

  node_pools_metadata = {
    all = {}
  }

  node_pools_taints = {
    all = []

    ondemand-node-pool = [
      {
        key    = "ondemand-node-pool"
        value  = true
        effect = "PREFER_NO_SCHEDULE"
      },
    ]
  }

  node_pools_tags = {
    all = []
  }
}

# Grant necessary permissions to the current service account for namespace creation
resource "google_project_iam_member" "paragon_installer_container_admin" {
  project = var.gcp_project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${data.google_client_openid_userinfo.me.email}"
}
