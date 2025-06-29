data "google_compute_instance" "vm" {
  project = var.project-name-and-id
  name = var.vm-name
  zone = var.gcp-zone
}

# create Instance group for the VM
resource "google_compute_instance_group" "instance-group" {
  project = var.project-name-and-id
  name        = "${var.instance-group-1-name-prefix}-${var.url-map-name}"
  instances = [
    data.google_compute_instance.vm.id,
  ]
  named_port {
    name = var.named-port-name
    port = var.named-port
  }
  zone = var.gcp-zone
}

# create global static external IP address used to reach the load balancer
resource "google_compute_global_address" "lb-static-ip" {
  project = var.project-name-and-id
  name         = "${var.lb-static-ip-name-prefix}-${var.url-map-name}"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# enable certificatemanager api
resource "google_project_service" "certificatemanager-api" {
  project = var.project-name-and-id
  service = "certificatemanager.googleapis.com"
}

# create Cert ca-demo-cert
resource "google_compute_managed_ssl_certificate" "cert" {
  project = var.project-name-and-id
  name = var.cert-name-prefix
  managed {
    domains = ["${google_compute_global_address.lb-static-ip.address}.nip.io"]
  }
}

# create Cloud Armor policy for only allowed IPs
resource "google_compute_security_policy" "cloudarmor-policy" {
  project = var.project-name-and-id
  name = "${var.cloudarmor-policy-name-prefix}-${var.url-map-name}"
  rule {
    action   = "allow"
    priority = "10000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["73.105.71.246/32","70.106.235.76/32"]
      }
    }
    description = "Trusted IPs"
  }
  rule {
    action   = "deny(403)"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default rule"
  }
}

### create Load balancer lb with instance group backend … multiple lines

# health check
resource "google_compute_health_check" "health-check" {
  project = var.project-name-and-id
  name     = "${var.health-check-name-prefix}-${var.url-map-name}"
  tcp_health_check {
    port = var.named-port
  }
}

# *** above uses HTTP, not TCP … diff between Haider's environment and this one

# backend service with custom request and response headers
resource "google_compute_backend_service" "backend-service" {
  project = var.project-name-and-id
  name                    = "${var.backend-service-name-prefix}-${var.url-map-name}"
  protocol                = var.backend-protocol
  port_name               = var.named-port-name
  load_balancing_scheme   = "EXTERNAL"
  timeout_sec             = 10
  enable_cdn              = false
#  security_policy         = google_compute_security_policy.cloudarmor-policy.id
  health_checks           = [google_compute_health_check.health-check.id]
  backend {
    group           = google_compute_instance_group.instance-group.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

# create Firewall rules for load balancer health check
resource "google_compute_firewall" "fwr-health-check" {
  project = var.project-name-and-id
  name    = var.fwr-health-check-name-prefix
  direction = "INGRESS"
  priority = "1000"
  network = var.vpc-name
  allow {
    protocol = "tcp"
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# url map
resource "google_compute_url_map" "url-map" {
  project = var.project-name-and-id
  name            = "${var.url-map-name}-${var.url-map-name}"
  default_service = google_compute_backend_service.backend-service.id
}

# https proxy
resource "google_compute_target_https_proxy" "proxy-https" {
  project = var.project-name-and-id
  name     = "${var.proxy-http-name-prefix}s-${var.url-map-name}"
  url_map  = google_compute_url_map.url-map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.id]
}

# forwarding rule for https
resource "google_compute_global_forwarding_rule" "forwarding-rule-https" {
  project = var.project-name-and-id
  name                  = "${var.forwarding-rule-name-prefix}-https-${var.url-map-name}"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.proxy-https.id
  ip_address            = google_compute_global_address.lb-static-ip.id
}

# http proxy
resource "google_compute_target_http_proxy" "proxy-http" {
  project = var.project-name-and-id
  name     = "${var.proxy-http-name-prefix}-${var.url-map-name}"
  url_map  = google_compute_url_map.url-map.id
}

# forwarding rule for http
resource "google_compute_global_forwarding_rule" "forwarding-rule-http" {
  project = var.project-name-and-id
  name                  = "${var.forwarding-rule-name-prefix}-http-${var.url-map-name}"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.proxy-http.id
  ip_address            = google_compute_global_address.lb-static-ip.id
}
