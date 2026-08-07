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
