/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/7-attachment_nat/terraform/variables.tf ---

# Project Identifier
variable "identifier" {
  type        = string
  description = "Project identifier, used as a suffix when naming resources."
  default     = "overlap"
}

# AWS Regions
variable "aws_regions" {
  type        = map(string)
  description = "AWS Regions to create the environment. Must match the edge-locations in the policy document."
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

# ---------- VPCs ----------
variable "nvirginia_vpcs" {
  type = map(object({
    segment                 = string
    number_azs              = number
    cidr_block              = string
    nat_cidr                = optional(string)
    workload_subnet_netmask = number
    endpoint_subnet_netmask = number
    cnetwork_subnet_netmask = number
    instance_type           = string
  }))
  description = "Information about the VPCs to create in us-east-1."

  default = {
    "shared" = {
      segment                 = "shared"
      number_azs              = 2
      cidr_block              = "10.0.0.0/16"
      workload_subnet_netmask = 28
      endpoint_subnet_netmask = 28
      cnetwork_subnet_netmask = 28
      instance_type           = "t2.micro"
    }
    "acquired-a" = {
      segment                 = "corporate"
      number_azs              = 2
      cidr_block              = "10.10.0.0/16"
      nat_cidr                = "100.64.0.0/16"
      workload_subnet_netmask = 28
      endpoint_subnet_netmask = 28
      cnetwork_subnet_netmask = 28
      instance_type           = "t2.micro"
    }
  }
}

variable "ireland_vpcs" {
  type = map(object({
    segment                 = string
    number_azs              = number
    cidr_block              = string
    nat_cidr                = optional(string)
    workload_subnet_netmask = number
    endpoint_subnet_netmask = number
    cnetwork_subnet_netmask = number
    instance_type           = string
  }))
  description = "Information about the VPCs to create in eu-west-1."

  default = {
    "acquired-b" = {
      segment                 = "corporate"
      number_azs              = 2
      cidr_block              = "10.10.0.0/16"
      nat_cidr                = "100.65.0.0/16"
      workload_subnet_netmask = 28
      endpoint_subnet_netmask = 28
      cnetwork_subnet_netmask = 28
      instance_type           = "t2.micro"
    }
  }
}

# ---------- OPTIONAL: SITE-TO-SITE VPN ----------
variable "site_to_site_vpn" {
  type = object({
    customer_gateway_ip  = string
    customer_gateway_asn = number
    onprem_cidr          = optional(string, "10.10.0.0/16")
    nat_cidr             = optional(string, "100.66.0.0/16")
  })
  description = "Site-to-Site VPN configuration, created in us-east-1. The customer gateway ASN must not overlap the asn-ranges in the policy document. onprem_cidr is translated to nat_cidr. null to skip."
  default     = null # the default skips it
}
