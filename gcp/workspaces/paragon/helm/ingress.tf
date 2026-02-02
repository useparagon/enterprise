locals {
  unique_domains = distinct([
    for service in values(var.public_services) :
    replace(replace(service.public_url, "https://", ""), "http://", "")
  ])

  # Create a hash of domains to version the certificate name
  # This allows create_before_destroy to work properly and avoid errors like:
  # Error: Error when reading or editing Managed Certificate: "paragon-x8973b3e-certificate":
  # googleapi: Error 400: Managed Certificate "paragon-x8973b3e-certificate" already exists
  domains_hash = substr(sha256(join(",", sort(local.unique_domains))), 0, 8)
}

resource "google_compute_managed_ssl_certificate" "cert" {
  name = "${var.workspace}-certificate-${local.domains_hash}"

  managed {
    domains = local.unique_domains
  }

  lifecycle {
    create_before_destroy = true
    # IMPORTANT: When domains change, GKE may not automatically update the target HTTPS proxy.
    # If you get "resourceInUseByAnotherResource" when deleting the old certificate:
    # 1. Find the target HTTPS proxy: kubectl describe ingress shared-ingress -n paragon | grep https-target-proxy
    # 2. Update it manually: gcloud compute target-https-proxies update <proxy-name> --ssl-certificates=<new-cert-name> --global
    # 3. Wait 1-2 minutes, then run terraform apply again to delete the old certificate
  }
}

resource "google_compute_global_address" "loadbalancer" {
  name = "${var.workspace}-loadbalancer"
}

resource "google_compute_region_url_map" "frontend_config" {
  name     = "${var.workspace}-frontend-config"
  region   = var.region
  provider = google-beta

  default_url_redirect {
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    https_redirect         = true
    strip_query            = false
  }
}

resource "kubectl_manifest" "frontend_config" {
  yaml_body = yamlencode({
    apiVersion = "networking.gke.io/v1beta1"
    kind       = "FrontendConfig"
    metadata = {
      name      = google_compute_region_url_map.frontend_config.name
      namespace = kubernetes_namespace_v1.paragon.id
    }
    spec = {
      redirect_to_https = {
        enabled = true
      }
    }
  })
}

# single ingress for all services to reduce the number of load balancers which
# keeps costs down and reduces the number of public IPs required in GCP quotas
resource "kubectl_manifest" "ingress" {
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "shared-ingress"
      namespace = kubernetes_namespace_v1.paragon.id
      annotations = {
        "kubernetes.io/ingress.allow-http"            = "true"
        "kubernetes.io/ingress.class"                 = var.ingress_scheme == "internal" ? "gce-internal" : "gce"
        "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.loadbalancer.name
        "networking.gke.io/v1beta1.FrontendConfig"    = google_compute_region_url_map.frontend_config.name
        "ingress.gcp.kubernetes.io/pre-shared-cert"   = google_compute_managed_ssl_certificate.cert.name
        "ingress.kubernetes.io/healthcheck-path"      = "/healthz"
        # Force ingress controller to update when certificate changes (must be string - annotations are string-only)
        "certificate-update-trigger" = tostring(google_compute_managed_ssl_certificate.cert.certificate_id)
      }
    }
    spec = {
      ingressClassName = var.ingress_scheme == "internal" ? "gce-internal" : "gce"
      loadBalancerIP   = google_compute_global_address.loadbalancer.address
      rules = [
        for name, svc in var.public_services : {
          host = replace(svc.public_url, "https://", "")
          http = {
            paths = [{
              path     = "/"
              pathType = "Prefix"
              backend = {
                service = {
                  name = name
                  port = {
                    number = svc.port
                  }
                }
              }
            }]
          }
        }
      ]
    }
  })

  depends_on = [
    helm_release.paragon_on_prem,
    helm_release.paragon_monitoring,
    helm_release.paragon_logging
  ]
}

# Grafana backend config for health checks
resource "kubectl_manifest" "grafana_backendconfig" {
  yaml_body = yamlencode({
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "grafana-backendconfig"
      namespace = kubernetes_namespace_v1.paragon.id
    }
    spec = {
      healthCheck = {
        requestPath        = "/api/health"
        port               = 4500
        checkIntervalSec   = 10
        timeoutSec         = 5
        healthyThreshold   = 2
        unhealthyThreshold = 2
      }
    }
  })
}
