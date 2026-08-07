/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/3-transit_gateway/terraform/main.tf ---

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
#
# The policy document is read from a file so that the SAME document is consumed by both
# this Terraform and the CloudFormation implementation. See V2.md section 6.
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

# ---------- RESOURCES IN N. VIRGINIA ----------
# Spoke VPCs.
#
# These attach to the TRANSIT GATEWAY, not to Cloud WAN. Compare with 1-basic and
# 2-inspection, where the VPC module is given a `core_network` block instead. Here the
# path to Cloud WAN is: VPC -> TGW route table -> TGW/Cloud WAN peering -> segment.
module "nvirginia_spoke_vpcs" {
  for_each  = var.nvirginia_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsnvirginia }

  name       = "${each.key}-${var.aws_regions.nvirginia}-${var.identifier}"
  cidr_block = each.value.cidr_block
  az_count   = each.value.number_azs

  transit_gateway_id = module.nvirginia_transit_gateway.transit_gateway_id
  transit_gateway_routes = {
    workload = "0.0.0.0/0"
  }

  subnets = {
    endpoints = { netmask = each.value.endpoint_subnet_netmask }
    workload  = { netmask = each.value.workload_subnet_netmask }
    transit_gateway = {
      netmask = each.value.tgw_subnet_netmask
    }
  }
}

# Transit Gateway, its route tables, the Cloud WAN peering, and the
# transit-gateway-route-table attachments (tagged `domain`).
module "nvirginia_transit_gateway" {
  source    = "../../tf_modules/transit_gateway"
  providers = { aws = aws.awsnvirginia }

  identifier      = var.identifier
  tgw_asn         = var.transit_gateway_asns.nvirginia
  core_network_id = awscc_networkmanager_core_network.core_network.core_network_id
  route_tables    = var.route_tables

  vpc_information = {
    for k, v in module.nvirginia_spoke_vpcs : k => {
      transit_gateway_attachment_id = v.transit_gateway_attachment_id
      route_table                   = var.nvirginia_spoke_vpcs[k].route_table
    }
  }
}

# EC2 instances (in the spoke VPCs) and an EC2 Instance Connect endpoint
module "nvirginia_compute" {
  for_each  = module.nvirginia_spoke_vpcs
  source    = "../../tf_modules/compute"
  providers = { aws = aws.awsnvirginia }

  identifier      = var.identifier
  vpc_name        = "${each.key}-${var.aws_regions.nvirginia}"
  vpc             = each.value
  vpc_information = var.nvirginia_spoke_vpcs[each.key]
}

# ---------- RESOURCES IN IRELAND ----------
module "ireland_spoke_vpcs" {
  for_each  = var.ireland_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsireland }

  name       = "${each.key}-${var.aws_regions.ireland}-${var.identifier}"
  cidr_block = each.value.cidr_block
  az_count   = each.value.number_azs

  transit_gateway_id = module.ireland_transit_gateway.transit_gateway_id
  transit_gateway_routes = {
    workload = "0.0.0.0/0"
  }

  subnets = {
    endpoints = { netmask = each.value.endpoint_subnet_netmask }
    workload  = { netmask = each.value.workload_subnet_netmask }
    transit_gateway = {
      netmask = each.value.tgw_subnet_netmask
    }
  }
}

module "ireland_transit_gateway" {
  source    = "../../tf_modules/transit_gateway"
  providers = { aws = aws.awsireland }

  identifier      = var.identifier
  tgw_asn         = var.transit_gateway_asns.ireland
  core_network_id = awscc_networkmanager_core_network.core_network.core_network_id
  route_tables    = var.route_tables

  vpc_information = {
    for k, v in module.ireland_spoke_vpcs : k => {
      transit_gateway_attachment_id = v.transit_gateway_attachment_id
      route_table                   = var.ireland_spoke_vpcs[k].route_table
    }
  }
}

module "ireland_compute" {
  for_each  = module.ireland_spoke_vpcs
  source    = "../../tf_modules/compute"
  providers = { aws = aws.awsireland }

  identifier      = var.identifier
  vpc_name        = "${each.key}-${var.aws_regions.ireland}"
  vpc             = each.value
  vpc_information = var.ireland_spoke_vpcs[each.key]
}
