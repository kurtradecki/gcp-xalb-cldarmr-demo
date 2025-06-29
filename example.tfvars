# This top section meant to be changed to fit your environment
  project-name-and-id = "<ENTER PROJECT ID HERE>"
  gcp-region = "<ENTER REGION HERE>"
  gcp-zone = "<ENTER ZONE HERE>"
  vpc-name = "<ENTER VPC NAME HERE>"
  vm-name = "<ENTER NAME OF VM WHERE APPLICAITON RUNS HERE>"

# Shouldn't need to change this section, though here just in case
  ext_allowed_ips       = ["0.0.0.0/32"] # eg ["1.2.3.4/32","5.6.7.0/24"] - must have at least 1 string value in the list - Public IP range(s) allowed in Cloud Armor for external LB, leave as is to deny all external IPs to reach the external load balancer. Visit https://whatismyipaddress.com/ or other sites like it to get your public IP address.
  named-port-name = "port80"
  named-port = "80"
  backend-protocol = "HTTP"

# No need to change anything below this line
  name-base = ""
  url-map-name = "lb-gxa"  # becomes the load balancer name for an application load balancer
  instance-group-1-name-prefix = "instgrp"
  cert-name-prefix = "cert"
  lb-static-ip-name-prefix = "static-ip"
  cloudarmor-policy-name-prefix = "cldarmr-pol"
  health-check-name-prefix = "hchck"
  forwarding-rule-name-prefix = "fr"
  proxy-http-name-prefix = "proxy-http"
  backend-service-name-prefix = "be"
  fwr-health-check-name-prefix = "fwr-hchck"
