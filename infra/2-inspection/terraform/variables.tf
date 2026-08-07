/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/2-inspection/terraform/variables.tf ---

# Project Identifier
variable "identifier" {
  type        = string
  description = "Project identifier, used as a suffix when naming resources."
  default     = "inspection"
}

# AWS Regions
#
# This pattern deploys two Regions. To add a third, add a provider alias in
# providers.tf, spoke VPC and inspection VPC module blocks in main.tf, and the Region
# to edge-locations in your policy document. See infra/README.md.
#
# NOTE: the baseline policy uses `send-via` with mode `dual-hop`, which requires an
# inspection attachment in EVERY Region of the participating segments. If you add a
# Region, add an inspection VPC there too, or switch the policy to `single-hop`.
variable "aws_regions" {
  type        = map(string)
  description = "AWS Regions to create the environment. Must match the edge-locations in the policy document."
  default = {
    nvirginia = "us-east-1"
    ireland   = "eu-west-1"
  }
}

# Cloud WAN network policy
#
# The default is this pattern's working baseline, which demonstrates both egress
# (`send-to`) and east-west (`send-via`) inspection. Point this at your own policy to
# deploy a different Cloud WAN configuration against the same infrastructure.
variable "policy_document" {
  type        = string
  description = "Path to the Cloud WAN network policy JSON document to deploy."
  default     = "../baseline.json"
}

# Definition of the spoke VPCs to create in N. Virginia Region
variable "nvirginia_spoke_vpcs" {
  type = map(object({
    segment                 = string
    number_azs              = number
    cidr_block              = string
    workload_subnet_netmask = number
    endpoint_subnet_netmask = number
    cnetwork_subnet_netmask = number
    instance_type           = string
  }))
  description = "Information about the spoke VPCs to create in us-east-1."

  default = {
    "prod" = {
      segment                 = "production"
      number_azs              = 2
      cidr_block              = "10.10.0.0/24"
      workload_subnet_netmask = 28
      endpoint_subnet_netmask = 28
      cnetwork_subnet_netmask = 28
      instance_type           = "t2.micro"
    }
    "dev" = {
      segment                 = "development"
      number_azs              = 2
      cidr_block              = "10.10.1.0/24"
      workload_subnet_netmask = 28
      endpoint_subnet_netmask = 28
      cnetwork_subnet_netmask = 28
      instance_type           = "t2.micro"
    }
  }
}

# Definition of the Inspection VPC to create in N. Virginia Region
variable "nvirginia_inspection_vpc" {
  type = object({
    cidr_block                = string
    number_azs                = number
    public_subnet_netmask     = number
    inspection_subnet_netmask = number
    cnetwork_subnet_netmask   = number
  })
  description = "Information about the Inspection VPC to create in us-east-1."

  default = {
    cidr_block                = "10.100.0.0/16"
    number_azs                = 2
    public_subnet_netmask     = 28
    inspection_subnet_netmask = 28
    cnetwork_subnet_netmask   = 28
  }
}

# Definition of the spoke VPCs to create in Ireland Region
variable "ireland_spoke_vpcs" {
  type = map(object({
    segment                 = string
    number_azs              = number
    cidr_block              = string
    workload_subnet_netmask = number
    endpoint_subnet_netmask = number
    cnetwork_subnet_netmask = number
    instance_type           = string
  }))
  description = "Information about the spoke VPCs to create in eu-west-1."

  default = {
    "prod" = {
      segment                 = "production"
      number_azs              = 2
      cidr_block              = "10.0.0.0/24"
      workload_subnet_netmask = 28
      endpoint_subnet_netmask = 28
      cnetwork_subnet_netmask = 28
      instance_type           = "t2.micro"
    }
    "dev" = {
      segment                 = "development"
      number_azs              = 2
      cidr_block              = "10.0.1.0/24"
      workload_subnet_netmask = 28
      endpoint_subnet_netmask = 28
      cnetwork_subnet_netmask = 28
      instance_type           = "t2.micro"
    }
  }
}

# Definition of the Inspection VPC to create in Ireland Region
variable "ireland_inspection_vpc" {
  type = object({
    cidr_block                = string
    number_azs                = number
    public_subnet_netmask     = number
    inspection_subnet_netmask = number
    cnetwork_subnet_netmask   = number
  })
  description = "Information about the Inspection VPC to create in eu-west-1."

  default = {
    cidr_block                = "10.100.0.0/16"
    number_azs                = 2
    public_subnet_netmask     = 28
    inspection_subnet_netmask = 28
    cnetwork_subnet_netmask   = 28
  }
}

# ---------- SECONDARY CIDR BLOCKS (opt-in) ----------
# Adds a secondary IPv4 CIDR block, with its own subnets, to every spoke VPC.
#
# OFF by default: it costs extra subnets and the pattern's baseline policy does not filter
# it, so it would propagate a range you did not ask for.
#
# Turn it on to work through policy/examples/filter_then_inspect.json, which needs a
# prefix that the routing policy actually drops:
#
#     terraform apply -var create_secondary_cidrs=true \
#       -var policy_document=../../../policy/examples/filter_then_inspect.json
#
# 100.64.0.0/16 is deliberately OUTSIDE 10.0.0.0/8, so an "allow 10.0.0.0/8, drop
# everything else" policy drops it while leaving the spoke and inspection VPC prefixes
# (both inside 10.0.0.0/8) intact.
variable "create_secondary_cidrs" {
  type        = bool
  description = "Add a secondary IPv4 CIDR block to each spoke VPC. Needed by the filter_then_inspect example."
  default     = false
}

variable "secondary_cidr_blocks" {
  type = object({
    nvirginia = string
    ireland   = string
    netmask   = number
  })
  description = "Secondary IPv4 CIDR block per Region, and the subnet netmask to carve from it."
  default = {
    nvirginia = "100.64.0.0/16"
    ireland   = "100.65.0.0/16"
    netmask   = 28
  }
}
