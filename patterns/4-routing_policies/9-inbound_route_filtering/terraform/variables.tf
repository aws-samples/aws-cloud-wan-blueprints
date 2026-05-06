/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/4-routing_policies/9-inbound_route_filtering/terraform/variables.tf ---

variable "identifier" {
  type        = string
  description = "Project Identifier."
  default     = "inbound-route-filtering"
}

variable "aws_regions" {
  type        = map(string)
  description = "AWS Regions for Cloud WAN edge locations."
  default = {
    nvirginia = "us-east-1"
    ireland   = "eu-west-1"
  }
}

variable "dx_gateway_asn" {
  type        = number
  description = "ASN for the Direct Connect Gateway."
  default     = 64512
}

variable "nvirginia_spoke_vpcs" {
  type        = any
  description = "VPCs to create in us-east-1."
  default = {
    "prod-us-east-1" = {
      segment                 = "production"
      number_azs              = 2
      cidr_block              = "10.0.0.0/16"
      workload_subnet_netmask = 24
      cnetwork_subnet_netmask = 28
    }
  }
}

variable "ireland_spoke_vpcs" {
  type        = any
  description = "VPCs to create in eu-west-1."
  default = {
    "prod-eu-west-1" = {
      segment                 = "production"
      number_azs              = 2
      cidr_block              = "10.10.0.0/16"
      workload_subnet_netmask = 24
      cnetwork_subnet_netmask = 28
    }
  }
}
