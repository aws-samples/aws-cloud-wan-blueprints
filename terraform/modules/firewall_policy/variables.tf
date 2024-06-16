/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- module/firewall_policy/variables.tf ---

variable "identifier" {
  description = "Project identifier."
  type        = string
}

variable "traffic_flow" {
  description = "Traffic flow (north-south or east-west)."
  type        = string
}