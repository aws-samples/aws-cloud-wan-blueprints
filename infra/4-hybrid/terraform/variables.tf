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
#
# `home` is Cloud WAN's home Region and is NOT an edge location - it exists only because
# managed prefix lists associated with a core network must be created there.
variable "aws_regions" {
  type        = map(string)
  description = "AWS Regions to create the environment. nvirginia and ireland must match the edge-locations in the policy document."
  default = {
    nvirginia = "us-east-1"
    ireland   = "eu-west-1"
    home      = "us-west-2"
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

# Site-to-Site VPN.
#
# Deployable with no on-premises equipment: the customer gateway is just an IP and an
# ASN. The attachment appears in Cloud WAN and associates to the `hybrid` segment, so you
# can observe attachment-type association and apply routing-policy labels. The TUNNELS
# stay DOWN until a real peer answers, so no routes are exchanged.
variable "site_to_site_vpn" {
  type = object({
    customer_gateway_ip  = string
    customer_gateway_asn = number
    region               = string
  })
  description = "Site-to-Site VPN configuration. null to skip."
  default     = null
}

# Direct Connect gateway.
#
# The gateway and its Cloud WAN attachment deploy with no circuit. Passing traffic needs
# a real Direct Connect connection and a virtual interface associated with the gateway,
# which cannot be simulated.
variable "direct_connect_gateway" {
  type = object({
    amazon_side_asn = number
  })
  description = "Direct Connect gateway configuration. null to skip."
  default     = null
}

# Connect (SD-WAN / Transit Gateway Connect).
#
# Rides on top of an existing VPC attachment (the transport attachment) and needs
# `inside-cidr-blocks` in the policy document. `peer_address` is the SD-WAN appliance's
# address; leave it null to create the Connect attachment without a peer.
variable "connect" {
  type = object({
    transport_vpc = string
    region        = string
    protocol      = string
    peer_address  = optional(string)
    peer_asn      = optional(number)
  })
  description = "Connect (SD-WAN) configuration. null to skip."
  default     = null
}

# ---------- SPOKE VPCs ----------
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

# ---------- PREFIX LISTS (route summarization) ----------
# Managed prefix lists in the HOME Region, associated with the core network under an
# alias. Route summarization policies match on these aliases. Prefix lists are free, so
# they are created by default - a summarization policy has nothing to match without them.
variable "create_prefix_lists" {
  type        = bool
  description = "Create managed prefix lists in the home Region and associate them with the core network."
  default     = true
}
