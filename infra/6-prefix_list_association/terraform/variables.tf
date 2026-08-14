/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/6-prefix_list_association/terraform/variables.tf ---

# Project Identifier
variable "identifier" {
  type        = string
  description = "Project identifier, used as a suffix when naming resources."
  default     = "prefix-list"
}

# AWS Regions
variable "aws_regions" {
  type        = map(string)
  description = "Region this deployment is managed from: oregon is Cloud WAN's home Region."
  default = {
    oregon = "us-west-2"
  }
}

# ---------- THE TWO POLICY DOCUMENTS ----------
# The core network is created with `policy_document`, which must NOT reference the prefix list alias - the association does not exist yet.
# Once it does, `prefix_list_policy_document` is attached, and that one may reference the alias.
variable "policy_document" {
  type        = string
  description = "Path to the policy the core network is created with. Must not reference the prefix list alias."
  default     = "../baseline.json"
}

variable "prefix_list_policy_document" {
  type        = string
  description = "Path to the policy attached after the prefix list association exists. This one references the prefix list alias."
  default     = "../baseline_prefix_list.json"
}

# ---------- PREFIX LIST ----------
variable "prefix_list_alias" {
  type        = string
  description = "Alias the prefix list is associated under. Must match the prefix-in-prefix-list value in the policy document."
  default     = "routesfiltered"
}

variable "prefix_list_cidrs" {
  type        = list(string)
  description = "CIDR blocks the prefix list contains. These are the prefixes a routing policy matches on by alias."
  default = [
    "10.100.0.0/16",
    "192.168.0.0/16"
  ]
}
