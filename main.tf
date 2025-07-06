/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

terraform {
  required_version = "~> 1.10.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.11.2"
    }
  }
}

# create VPC and subnets
module "vpc" {
  source     = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc?ref=v36.0.0"
  project_id = var.project_id
  name       = var.vpc_name
  subnets = [merge(var.vpc_subnets, {
    region = var.gcp_region
  })]
}

# Public NAT for web server to download nginx
module "cldnat-websrvr" {
  source         = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat?ref=v36.0.0"
  project_id     = var.project_id
  region         = var.gcp_region
  name           = "${var.cldnat_name}-${var.vpc_name}"
  router_network = var.vpc_name
  depends_on = [ module.vpc ]
}

# create web server VM
resource "google_compute_instance" "websrvr_vm" {
  boot_disk {
    auto_delete = true
    device_name = "websrvr"

    initialize_params {
      image = "projects/debian-cloud/global/images/debian-12-bookworm-v20250610"
      size  = 10
      type  = "pd-balanced"
    }

    mode = "READ_WRITE"
  }
  machine_type = "e2-micro"
  name = var.vm_name
  metadata = {
    enable-osconfig = "TRUE"
    enable-oslogin  = "true"
    startup-script  = "sudo apt-get update\nsudo apt-get install -y nginx\nsudo systemctl start nginx"
  }
  network_interface {
    stack_type         = "IPV4_ONLY"
    subnetwork         = "https://www.googleapis.com/compute/v1/projects/${var.project_id}/regions/${var.gcp_region}/subnetworks/${var.vpc_subnets.name}"
  }
  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }
  project = var.project_id
  zone = "${var.gcp_region}${var.gcp_zone_suffix}"
  depends_on = [ module.vpc, module.cldnat-websrvr ]
}

# create Instance group for the VM
resource "google_compute_instance_group" "instance-group" {
  project = var.project_id
  name    = "${var.instance_group_1_name_prefix}-${var.url_map_name}"
  instances = [
    google_compute_instance.websrvr_vm.id,
  ]
  named_port {
    name = var.named_port_name
    port = var.named_port
  }
  zone = "${var.gcp_region}${var.gcp_zone_suffix}"
}

# create global static external IP address used to reach the load balancer
resource "google_compute_global_address" "lb-static-ip" {
  project      = var.project_id
  name         = "${var.lb_static_ip_name_prefix}-${var.url_map_name}"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# enable certificatemanager api
resource "google_project_service" "certificatemanager-api" {
  project = var.project_id
  service = "certificatemanager.googleapis.com"
}

# create Cert ca-demo-cert
resource "google_compute_managed_ssl_certificate" "cert" {
  project = var.project_id
  name    = var.cert_name_prefix
  managed {
    domains = ["${google_compute_global_address.lb-static-ip.address}.nip.io"]
  }
}

# create firewall rule to allow SSH from IAP IP range
resource "google_compute_firewall" "fwr-ssh-iap-range" {
  project   = var.project_id
  name      = var.fwr_ssh_iap
  direction = "INGRESS"
  priority  = "1000"
  network   = var.vpc_name
  allow {
    protocol = "tcp"
  }
  source_ranges = ["35.235.240.0/20"]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
  depends_on = [ module.vpc ]
}

# create Cloud Armor policy for only allowed IPs
resource "google_compute_security_policy" "cloudarmor-policy" {
  project = var.project_id
  name    = "${var.cloudarmor_policy_name_prefix}-${var.url_map_name}"
  rule {
    action   = "allow"
    priority = "10000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.ext_allowed_ips
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
  project = var.project_id
  name    = "${var.health_check_name_prefix}-${var.url_map_name}"
  tcp_health_check {
    port = var.named_port
  }
}

# backend service with custom request and response headers
resource "google_compute_backend_service" "backend-service" {
  project               = var.project_id
  name                  = "${var.backend_service_name_prefix}-${var.url_map_name}"
  protocol              = var.backend_protocol
  port_name             = var.named_port_name
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 10
  enable_cdn            = false
  security_policy         = google_compute_security_policy.cloudarmor-policy.id
  health_checks = [google_compute_health_check.health-check.id]
  backend {
    group           = google_compute_instance_group.instance-group.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

# create Firewall rules for load balancer health check
resource "google_compute_firewall" "fwr-health-check" {
  project   = var.project_id
  name      = var.fwr_health_check_name_prefix
  direction = "INGRESS"
  priority  = "1000"
  network   = var.vpc_name
  allow {
    protocol = "tcp"
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
  depends_on = [ module.vpc ]
}

# url map
resource "google_compute_url_map" "url-map" {
  project         = var.project_id
  name            = "${var.url_map_name}"
  default_service = google_compute_backend_service.backend-service.id
}

# https proxy
resource "google_compute_target_https_proxy" "proxy-https" {
  project          = var.project_id
  name             = "${var.proxy_http_name_prefix}s-${var.url_map_name}"
  url_map          = google_compute_url_map.url-map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.id]
}

# forwarding rule for https
resource "google_compute_global_forwarding_rule" "forwarding-rule-https" {
  project               = var.project_id
  name                  = "${var.forwarding_rule_name_prefix}-https-${var.url_map_name}"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.proxy-https.id
  ip_address            = google_compute_global_address.lb-static-ip.id
}

# http proxy
resource "google_compute_target_http_proxy" "proxy-http" {
  project = var.project_id
  name    = "${var.proxy_http_name_prefix}-${var.url_map_name}"
  url_map = google_compute_url_map.url-map.id
}

# forwarding rule for http
resource "google_compute_global_forwarding_rule" "forwarding-rule-http" {
  project               = var.project_id
  name                  = "${var.forwarding_rule_name_prefix}-http-${var.url_map_name}"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.proxy-http.id
  ip_address            = google_compute_global_address.lb-static-ip.id
}
