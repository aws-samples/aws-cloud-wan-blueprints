/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/4-hybrid/terraform/main.tf ---

data "aws_partition" "current" {
  provider = aws.awsnvirginia
}

data "aws_caller_identity" "current" {
  provider = aws.awsnvirginia
}

# ---------- AWS CLOUD WAN ----------
# Global Network
resource "awscc_networkmanager_global_network" "global_network" {
  provider = awscc.awsccnvirginia

  description = "Global Network - ${var.identifier}"

  tags = [{
    key   = "Name"
    value = "global-network-${var.identifier}"
  }]
}

# Core Network
resource "awscc_networkmanager_core_network" "core_network" {
  provider = awscc.awsccnvirginia

  global_network_id = awscc_networkmanager_global_network.global_network.id
  description       = "Core Network - ${var.identifier}"
  policy_document   = file(var.policy_document)

  tags = [{
    key   = "Name"
    value = "core-network-${var.identifier}"
  }]
}

# ---------- HYBRID: SITE-TO-SITE VPN ----------
# Customer gateway
resource "aws_customer_gateway" "cgw" {
  count    = var.site_to_site_vpn != null ? 1 : 0
  provider = aws.awsnvirginia

  bgp_asn    = var.site_to_site_vpn.customer_gateway_asn
  ip_address = var.site_to_site_vpn.customer_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name = "cgw-${var.identifier}"
  }
}

# AWS Cloud WAN VPN attachment
resource "aws_networkmanager_site_to_site_vpn_attachment" "vpn_attachment" {
  count    = var.site_to_site_vpn != null ? 1 : 0
  provider = aws.awsnvirginia

  core_network_id    = awscc_networkmanager_core_network.core_network.core_network_id
  vpn_connection_arn = aws_vpn_connection.vpn[0].arn

  tags = {
    Name = "vpn-attachment-${var.identifier}"
  }
}

# VPN connection
resource "aws_vpn_connection" "vpn" {
  count    = var.site_to_site_vpn != null ? 1 : 0
  provider = aws.awsnvirginia

  customer_gateway_id = aws_customer_gateway.cgw[0].id
  type                = aws_customer_gateway.cgw[0].type

  tags = {
    Name = "vpn-${var.identifier}"
  }
}

# ---------- HYBRID: DIRECT CONNECT GATEWAY ----------
# Direct Connect gateway
resource "aws_dx_gateway" "dxgw" {
  count    = var.direct_connect_gateway != null ? 1 : 0
  provider = aws.awsnvirginia

  name            = "dxgw-${var.identifier}"
  amazon_side_asn = var.direct_connect_gateway.amazon_side_asn
}

# AWS Cloud WAN direct connect gateway attachment
resource "aws_networkmanager_dx_gateway_attachment" "dxgw_attachment" {
  count = var.direct_connect_gateway != null ? 1 : 0

  core_network_id            = awscc_networkmanager_core_network.core_network.core_network_id
  direct_connect_gateway_arn = "arn:${data.aws_partition.current.partition}:directconnect::${data.aws_caller_identity.current.account_id}:dx-gateway/${aws_dx_gateway.dxgw[0].id}"
  edge_locations             = [var.aws_regions.nvirginia, var.aws_regions.ireland]

  tags = {
    Name = "dxgw-attachment-${var.identifier}"
  }
}

# ---------- RESOURCES IN N. VIRGINIA ----------
module "nvirginia_spoke_vpc" {
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsnvirginia }

  name       = "spoke-${var.aws_regions.nvirginia}-${var.identifier}"
  cidr_block = var.nvirginia_spoke_vpc.cidr_block
  az_count   = var.nvirginia_spoke_vpc.number_azs

  core_network = {
    id  = awscc_networkmanager_core_network.core_network.core_network_id
    arn = awscc_networkmanager_core_network.core_network.core_network_arn
  }
  core_network_routes = {
    workload = "0.0.0.0/0"
  }

  subnets = {
    endpoints = { netmask = var.nvirginia_spoke_vpc.endpoint_subnet_netmask }
    workload  = { netmask = var.nvirginia_spoke_vpc.workload_subnet_netmask }
    core_network = {
      netmask            = var.nvirginia_spoke_vpc.cnetwork_subnet_netmask
      require_acceptance = false
    }
  }
}

module "nvirginia_compute" {
  source    = "../../tf_modules/compute"
  providers = { aws = aws.awsnvirginia }

  identifier      = var.identifier
  vpc_name        = "spoke-${var.aws_regions.nvirginia}"
  vpc             = module.nvirginia_spoke_vpc
  vpc_information = var.nvirginia_spoke_vpc
}

# ---------- RESOURCES IN IRELAND ----------
module "ireland_spoke_vpc" {
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsireland }

  name       = "spoke-${var.aws_regions.ireland}-${var.identifier}"
  cidr_block = var.ireland_spoke_vpc.cidr_block
  az_count   = var.ireland_spoke_vpc.number_azs

  core_network = {
    id  = awscc_networkmanager_core_network.core_network.core_network_id
    arn = awscc_networkmanager_core_network.core_network.core_network_arn
  }
  core_network_routes = {
    workload = "0.0.0.0/0"
  }

  subnets = {
    endpoints = { netmask = var.ireland_spoke_vpc.endpoint_subnet_netmask }
    workload  = { netmask = var.ireland_spoke_vpc.workload_subnet_netmask }
    core_network = {
      netmask            = var.ireland_spoke_vpc.cnetwork_subnet_netmask
      require_acceptance = false
    }
  }
}

module "ireland_compute" {
  source    = "../../tf_modules/compute"
  providers = { aws = aws.awsireland }

  identifier      = var.identifier
  vpc_name        = "spoke-${var.aws_regions.ireland}"
  vpc             = module.ireland_spoke_vpc
  vpc_information = var.ireland_spoke_vpc
}
