/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/3-transit_gateway/terraform/variables.tf ---

# Project Identifier
variable "identifier" {
  type        = string
  description = "Project identifier, used as a suffix when naming resources."
  default     = "transit-gateway"
}

# AWS Regions
#
# This pattern deploys two Regions. To add a third, add a provider alias in
# providers.tf, VPC and Transit Gateway module blocks in main.tf, and the Region to
# edge-locations in your policy document. See infra/README.md.
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

# Transit Gateway ASNs
#
# These MUST NOT overlap the core network's asn-ranges (64520-64525 in the baseline).
# A Transit Gateway and a Core Network Edge sharing an ASN breaks BGP path selection in
# ways that look like intermittent blackholing.
variable "transit_gateway_asns" {
  type        = map(number)
  description = "Amazon-side ASN for the Transit Gateway in each Region. Must not overlap the asn-ranges in the policy document."
  default = {
    nvirginia = 64532
    ireland   = 64533
  }
}

# Definition of the spoke VPCs to create in N. Virginia Region.
#
# NOTE: these attach to the TRANSIT GATEWAY, not directly to Cloud WAN. `segment`
# selects which Transit Gateway route table the VPC is associated with, which in turn
# determines the Cloud WAN segment it reaches through.
variable "nvirginia_spoke_vpcs" {
  type = map(object({
    segment                 = string
    number_azs              = number
    cidr_block              = string
    workload_subnet_netmask = number
    endpoint_subnet_netmask = number
    tgw_subnet_netmask      = number
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
      tgw_subnet_netmask      = 28
      instance_type           = "t2.micro"
    }
    "dev" = {
      segment                 = "development"
      number_azs              = 2
      cidr_block              = "10.10.1.0/24"
      workload_subnet_netmask = 28
      endpoint_subnet_netmask = 28
      tgw_subnet_netmask      = 28
      instance_type           = "t2.micro"
    }
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
    tgw_subnet_netmask      = number
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
      tgw_subnet_netmask      = 28
      instance_type           = "t2.micro"
    }
    "dev" = {
      segment                 = "development"
      number_azs              = 2
      cidr_block              = "10.0.1.0/24"
      workload_subnet_netmask = 28
      endpoint_subnet_netmask = 28
      tgw_subnet_netmask      = 28
      instance_type           = "t2.micro"
    }
  }
}
