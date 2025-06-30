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

# This top section meant to be changed to fit your environment
project_id      = "<ENTER PROJECT ID HERE>" 
gcp_region      = "<ENTER REGION HERE>" # eg "us-central1"
gcp_zone_suffix = "<ENTER ZONE HERE>" # eg "-c", will be added to the end of gcp_region for the zone

# Shouldn't need to change this section, though here just in case
ext_allowed_ips  = ["0.0.0.0/32"] # eg ["1.2.3.4/32","5.6.7.0/24"] - must have at least 1 string value in the list - Public IP range(s) allowed in Cloud Armor for external LB, leave as ["0.0.0.0/32"] to deny all external IPs to reach the external load balancer. Visit https://whatismyipaddress.com/ or other sites like it to get your public IP address.
named_port_name  = "port80"
named_port       = "80"
backend_protocol = "HTTP"

# No need to change anything below this line
vm_name                       = "websrvr"
cldnat_name                   = "pubnat"
url_map_name                  = "lb-gxa" # becomes the load balancer name for an application load balancer
instance_group_1_name_prefix  = "instgrp"
cert_name_prefix              = "cert"
lb_static_ip_name_prefix      = "static-ip"
cloudarmor_policy_name_prefix = "cldarmr-pol"
health_check_name_prefix      = "hchck"
forwarding_rule_name_prefix   = "fr"
proxy_http_name_prefix        = "proxy-http"
backend_service_name_prefix   = "be"
fwr_health_check_name_prefix  = "fwr-hchck"

# VPCs / subnets config
vpc_name = "vpc"
vpc_subnets = {
  name               = "subnet"
  ip_cidr_range      = "10.1.1.0/24"
  secondary_ip_range = null
  flow_logs_config = {
    flow_sampling        = 1.0
    aggregation_interval = "INTERVAL_5_SEC"
    metadata             = "INCLUDE_ALL_METADATA"
  }
}