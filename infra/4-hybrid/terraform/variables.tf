/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/4-hybrid/terraform/variables.tf ---

# Project Identifier
variable "identifier" {
  type        = string
  description = "Project identifier, used as a suffix when naming resources."
  default     = "hybrid"
}

# AWS Regions
variable "aws_regions" {
  type        = map(string)
  description = "AWS Regions to create the environment. nvirginia and ireland must match the edge-locations in the policy document."
  default = {
    nvirginia = "us-east-1"
    ireland   = "eu-west-1"
  }
}

# Cloud WAN network policy
variable "policy_document" {
  type        = string
  description = "Path to the Cloud WAN network policy JSON document to deploy."
  default     = "../baseline.json"
}

# ---------- HYBRID SUB-TYPES: each is independently optional ----------
# Set a sub-type to null (the default) to skip it. Their prerequisites differ a lot, so
# enable only the ones you can actually test - see the pattern README.

# Site-to-Site VPN
variable "site_to_site_vpn" {
  type = object({
    customer_gateway_ip  = string
    customer_gateway_asn = number
  })
  description = "Site-to-Site VPN configuration, created in us-east-1. The customer gateway ASN must not overlap the asn-ranges in the policy document. null to skip."
  default     = null
}

# Direct Connect gateway.
variable "direct_connect_gateway" {
  type = object({
    amazon_side_asn = number
  })
  description = "Direct Connect gateway configuration. The Amazon-side ASN must not overlap the asn-ranges in the policy document. null to skip."
  default     = null
}

# ---------- SPOKE VPCs ----------
variable "nvirginia_spoke_vpc" {
  type = object({
    number_azs              = number
    cidr_block              = string
    workload_subnet_netmask = number
    endpoint_subnet_netmask = number
    cnetwork_subnet_netmask = number
    instance_type           = string
  })
  description = "Information about the spoke VPC to create in us-east-1."

  default = {
    number_azs              = 2
    cidr_block              = "10.10.0.0/24"
    workload_subnet_netmask = 28
    endpoint_subnet_netmask = 28
    cnetwork_subnet_netmask = 28
    instance_type           = "t2.micro"
  }
}

variable "ireland_spoke_vpc" {
  type = object({
    number_azs              = number
    cidr_block              = string
    workload_subnet_netmask = number
    endpoint_subnet_netmask = number
    cnetwork_subnet_netmask = number
    instance_type           = string
  })
  description = "Information about the spoke VPC to create in eu-west-1."

  default = {
    number_azs              = 2
    cidr_block              = "10.0.0.0/24"
    workload_subnet_netmask = 28
    endpoint_subnet_netmask = 28
    cnetwork_subnet_netmask = 28
    instance_type           = "t2.micro"
  }
}
