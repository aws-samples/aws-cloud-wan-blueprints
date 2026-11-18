/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/7-attachment_nat/terraform/main.tf ---

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

# ---------- RESOURCES IN N. VIRGINIA ----------
# VPCs - definition in variables.tf
module "nvirginia_vpcs" {
  for_each  = var.nvirginia_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.9.0"
  providers = { aws = aws.awsnvirginia }

  name       = "${each.key}-${var.aws_regions.nvirginia}-${var.identifier}"
  cidr_block = each.value.cidr_block
  az_count   = each.value.number_azs

  subnets = {
    endpoints = { netmask = each.value.endpoint_subnet_netmask }
    workload  = { netmask = each.value.workload_subnet_netmask }
    cwan      = { netmask = each.value.cnetwork_subnet_netmask }
  }
}

# AWS Cloud WAN attachments - VPCs without 1:1 NAT
resource "awscc_networkmanager_vpc_attachment" "nvirginia" {
  for_each = { for k, v in module.nvirginia_vpcs : k => v if var.nvirginia_vpcs[k].nat_cidr == null }
  provider = awscc.awsccnvirginia

  core_network_id = awscc_networkmanager_core_network.core_network.core_network_id
  vpc_arn         = each.value.vpc_attributes.arn
  subnet_arns     = [for k, v in each.value.private_subnet_attributes_by_az : v.arn if split("/", k)[0] == "cwan"]

  tags = [
    {
      key   = "Name"
      value = "${each.key}-vpc-attachment-${var.aws_regions.nvirginia}-${var.identifier}"
    },
    {
      key   = "domain"
      value = var.nvirginia_vpcs[each.key].segment
    }
  ]
}

# AWS Cloud WAN attachments - VPCs with 1:1 NAT (cidr_block translated to nat_cidr)
resource "awscc_networkmanager_vpc_attachment" "nvirginia_nat" {
  for_each = { for k, v in module.nvirginia_vpcs : k => v if var.nvirginia_vpcs[k].nat_cidr != null }
  provider = awscc.awsccnvirginia

  core_network_id = awscc_networkmanager_core_network.core_network.core_network_id
  vpc_arn         = each.value.vpc_attributes.arn
  subnet_arns     = [for k, v in each.value.private_subnet_attributes_by_az : v.arn if split("/", k)[0] == "cwan"]

  nat_gateway_support = "ENABLE"
  nat_gateway_rules = [{
    rule_number       = 100
    match_source_cidr = var.nvirginia_vpcs[each.key].cidr_block
    nat_cidr          = var.nvirginia_vpcs[each.key].nat_cidr
  }]

  tags = [
    {
      key   = "Name"
      value = "${each.key}-nat-attachment-${var.aws_regions.nvirginia}-${var.identifier}"
    },
    {
      key   = "domain"
      value = var.nvirginia_vpcs[each.key].segment
    }
  ]
}

# Default route to the core network in the workload subnets (the VPC local route still wins for the VPC's own CIDR)
resource "aws_route" "nvirginia_cwan_route" {
  for_each = merge([
    for vpc, m in module.nvirginia_vpcs : {
      for k, rt in m.rt_attributes_by_type_by_az.private : "${vpc}/${k}" => rt.id if split("/", k)[0] == "workload"
    }
  ]...)
  provider = aws.awsnvirginia

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  core_network_arn       = awscc_networkmanager_core_network.core_network.core_network_arn

  depends_on = [awscc_networkmanager_vpc_attachment.nvirginia, awscc_networkmanager_vpc_attachment.nvirginia_nat]
}

# EC2 instances (in the VPCs) and an EC2 Instance Connect endpoint
module "nvirginia_compute" {
  for_each  = module.nvirginia_vpcs
  source    = "../../tf_modules/compute"
  providers = { aws = aws.awsnvirginia }

  identifier      = var.identifier
  vpc_name        = "${each.key}-${var.aws_regions.nvirginia}"
  vpc             = each.value
  vpc_information = var.nvirginia_vpcs[each.key]
}

# ---------- OPTIONAL: SITE-TO-SITE VPN (N. VIRGINIA) ----------
# Customer gateway
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

# VPN connection (BGP)
resource "aws_vpn_connection" "vpn" {
  count    = var.site_to_site_vpn != null ? 1 : 0
  provider = aws.awsnvirginia

  customer_gateway_id = aws_customer_gateway.cgw[0].id
  type                = aws_customer_gateway.cgw[0].type

  tags = {
    Name = "vpn-${var.identifier}"
  }
}

# AWS Cloud WAN VPN attachment, with 1:1 NAT.
# nat_system_route_support = true (the default) installs a SYSTEM route for nat_cidr. Set it to false to advertise nat_cidr from your own BGP peers instead.
resource "awscc_networkmanager_site_to_site_vpn_attachment" "vpn_attachment" {
  count    = var.site_to_site_vpn != null ? 1 : 0
  provider = awscc.awsccnvirginia

  core_network_id    = awscc_networkmanager_core_network.core_network.core_network_id
  vpn_connection_arn = aws_vpn_connection.vpn[0].arn

  nat_gateway_support      = "ENABLE"
  nat_system_route_support = true
  nat_gateway_rules = [{
    rule_number       = 100
    match_source_cidr = var.site_to_site_vpn.onprem_cidr
    nat_cidr          = var.site_to_site_vpn.nat_cidr
  }]

  tags = [{
    key   = "Name"
    value = "vpn-nat-attachment-${var.identifier}"
  }]
}

# ---------- RESOURCES IN IRELAND ----------
# VPCs - definition in variables.tf
module "ireland_vpcs" {
  for_each  = var.ireland_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.9.0"
  providers = { aws = aws.awsireland }

  name       = "${each.key}-${var.aws_regions.ireland}-${var.identifier}"
  cidr_block = each.value.cidr_block
  az_count   = each.value.number_azs

  subnets = {
    endpoints = { netmask = each.value.endpoint_subnet_netmask }
    workload  = { netmask = each.value.workload_subnet_netmask }
    cwan      = { netmask = each.value.cnetwork_subnet_netmask }
  }
}

# AWS Cloud WAN attachments - VPCs with 1:1 NAT (cidr_block translated to nat_cidr)
resource "awscc_networkmanager_vpc_attachment" "ireland_nat" {
  for_each = { for k, v in module.ireland_vpcs : k => v if var.ireland_vpcs[k].nat_cidr != null }
  provider = awscc.awsccireland

  core_network_id = awscc_networkmanager_core_network.core_network.core_network_id
  vpc_arn         = each.value.vpc_attributes.arn
  subnet_arns     = [for k, v in each.value.private_subnet_attributes_by_az : v.arn if split("/", k)[0] == "cwan"]

  nat_gateway_support = "ENABLE"
  nat_gateway_rules = [{
    rule_number       = 100
    match_source_cidr = var.ireland_vpcs[each.key].cidr_block
    nat_cidr          = var.ireland_vpcs[each.key].nat_cidr
  }]

  tags = [
    {
      key   = "Name"
      value = "${each.key}-nat-attachment-${var.aws_regions.ireland}-${var.identifier}"
    },
    {
      key   = "domain"
      value = var.ireland_vpcs[each.key].segment
    }
  ]
}

# Default route to the core network in the workload subnets
resource "aws_route" "ireland_cwan_route" {
  for_each = merge([
    for vpc, m in module.ireland_vpcs : {
      for k, rt in m.rt_attributes_by_type_by_az.private : "${vpc}/${k}" => rt.id if split("/", k)[0] == "workload"
    }
  ]...)
  provider = aws.awsireland

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  core_network_arn       = awscc_networkmanager_core_network.core_network.core_network_arn

  depends_on = [awscc_networkmanager_vpc_attachment.ireland_nat]
}

# EC2 instances (in the VPCs) and an EC2 Instance Connect endpoint
module "ireland_compute" {
  for_each  = module.ireland_vpcs
  source    = "../../tf_modules/compute"
  providers = { aws = aws.awsireland }

  identifier      = var.identifier
  vpc_name        = "${each.key}-${var.aws_regions.ireland}"
  vpc             = each.value
  vpc_information = var.ireland_vpcs[each.key]
}
