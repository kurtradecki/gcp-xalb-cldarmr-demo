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

variable project-name-and-id {
  type = string
}

variable ext_allowed_ips {
  type = string
}

variable gcp-region {
  type = string    
}

variable gcp-zone {
  type = string    
}

variable vpc-name {
  type = string    
}

variable url-map-name {
  type = string    
}

variable vm-name {
  type = string    
}

variable instance-group-1-name-prefix {
    type = string
}

variable cert-name-prefix {
  type = string
}

variable lb-static-ip-name-prefix {
  type = string    
}

variable cloudarmor-policy-name-prefix{
  type = string
}

variable health-check-name-prefix {
  type = string
}

variable forwarding-rule-name-prefix {
  type = string    
}

variable proxy-http-name-prefix {
  type = string   
}

variable backend-service-name-prefix {
  type = string
}

variable fwr-health-check-name-prefix {
  type = string
}

variable named-port-name {
  type = string
}

variable named-port {
  type = string
}

variable backend-protocol {
  type = string
}

variable name-base {
  type = string
}
