# HTTPS LB + Cloud CDN; private GCS via SigV4 (HMAC). Default cert is self-signed on the LB IP.

resource "google_storage_hmac_key" "cdn_origin" {
  service_account_email = google_service_account.minio.email
}

resource "google_compute_global_address" "cdn" {
  name    = "${var.workspace}-cdn-lb-ip"
  project = var.gcp_project_id
}

resource "tls_private_key" "cdn_lb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "cdn_lb" {
  depends_on = [google_compute_global_address.cdn]

  private_key_pem       = tls_private_key.cdn_lb.private_key_pem
  validity_period_hours = 8760
  allowed_uses          = ["server_auth", "digital_signature", "key_encipherment"]

  subject {
    common_name = "${var.workspace} Paragon CDN"
  }

  ip_addresses = [google_compute_global_address.cdn.address]
}

resource "google_compute_ssl_certificate" "cdn" {
  name        = "${substr(var.workspace, 0, 12)}-cdn-cert"
  project     = var.gcp_project_id
  certificate = tls_self_signed_cert.cdn_lb.cert_pem
  private_key = tls_private_key.cdn_lb.private_key_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_global_network_endpoint_group" "cdn" {
  provider              = google-beta
  name                  = "${var.workspace}-cdn-neg"
  project               = var.gcp_project_id
  default_port          = 443
  network_endpoint_type = "INTERNET_FQDN_PORT"
}

resource "google_compute_global_network_endpoint" "cdn_storage" {
  provider                      = google-beta
  project                       = var.gcp_project_id
  global_network_endpoint_group = google_compute_global_network_endpoint_group.cdn.name
  fqdn                          = "storage.googleapis.com"
  port                          = 443
}

resource "google_compute_backend_service" "cdn" {
  provider = google-beta

  name                  = "${var.workspace}-cdn-bs"
  project               = var.gcp_project_id
  protocol              = "HTTPS"
  port_name             = "https"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"
  locality_lb_policy    = "ROUND_ROBIN"

  security_settings {
    aws_v4_authentication {
      access_key_id    = google_storage_hmac_key.cdn_origin.access_id
      access_key       = google_storage_hmac_key.cdn_origin.secret
      origin_region    = var.region
      access_key_version = "v1"
    }
  }

  backend {
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
    group           = google_compute_global_network_endpoint_group.cdn.id
  }

  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    client_ttl                   = 3600
    default_ttl                  = 3600
    max_ttl                      = 86400
    negative_caching             = true
    serve_while_stale            = 86400
    signed_url_cache_max_age_sec = 3600
  }
}

resource "google_compute_url_map" "cdn" {
  provider = google-beta

  name            = "${var.workspace}-cdn-urlmap"
  project         = var.gcp_project_id
  default_service = google_compute_backend_service.cdn.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "paths"
  }

  path_matcher {
    name = "paths"

    default_route_action {
      url_rewrite {
        path_prefix_rewrite = "/${google_storage_bucket.cdn.name}/"
      }

      weighted_backend_services {
        backend_service = google_compute_backend_service.cdn.id
        weight          = 100
      }
    }
  }
}

resource "google_compute_target_https_proxy" "cdn" {
  provider = google-beta

  name             = "${var.workspace}-cdn-https-proxy"
  project          = var.gcp_project_id
  url_map          = google_compute_url_map.cdn.id
  ssl_certificates = [google_compute_ssl_certificate.cdn.id]
}

resource "google_compute_global_forwarding_rule" "cdn" {
  provider = google-beta

  name                  = "${var.workspace}-cdn-fr"
  project               = var.gcp_project_id
  target                = google_compute_target_https_proxy.cdn.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.cdn.id
}
