/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/4-advanced_routing/8-filtering_peered_tgw/terraform/main.tf ---

# ---------- AWS CLOUD WAN RESOURCES ----------
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

  policy_document = data.aws_networkmanager_core_network_policy_document.policy_document.json

  tags = [{
    key   = "Name"
    value = "core-network-${var.identifier}"
  }]
}

# ---------- RESOURCES IN IRELAND ----------
# AWS Transit Gateway
resource "aws_ec2_transit_gateway" "ireland_tgw" {
  provider = aws.awsireland

  description                     = "Transit Gateway - ${var.identifier}"
  amazon_side_asn                 = var.tgw_asn.ireland
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name = "tgw-ireland-${var.identifier}"
  }
}

# Spoke VPC - definition in variables.tf
module "ireland_spoke_vpcs" {
  for_each  = var.ireland_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsireland }

  name       = each.key
  cidr_block = each.value.cidr_block
  az_count   = each.value.number_azs

  vpc_assign_generated_ipv6_cidr_block = true

  transit_gateway_id = aws_ec2_transit_gateway.ireland_tgw.id
  transit_gateway_routes = {
    workload = "0.0.0.0/0"
  }
  transit_gateway_ipv6_routes = {
    workload = "::/0"
  }

  subnets = {
    endpoints = {
      netmask          = each.value.endpoint_subnet_netmask
      assign_ipv6_cidr = true
    }
    workload = {
      netmask          = each.value.workload_subnet_netmask
      assign_ipv6_cidr = true
    }
    transit_gateway = {
      netmask          = each.value.tgw_subnet_netmask
      assign_ipv6_cidr = true
    }
  }
}

# EC2 Instances (in Spoke VPCs) and EC2 Instance Connect endpoint
module "ireland_compute" {
  for_each  = module.ireland_spoke_vpcs
  source    = "../../../tf_modules/compute"
  providers = { aws = aws.awsireland }

  identifier      = var.identifier
  vpc_name        = each.key
  vpc             = each.value
  vpc_information = var.ireland_spoke_vpcs[each.key]
}

# AWS Transit Gateway route table
resource "aws_ec2_transit_gateway_route_table" "ireland_tgw_rt" {
  provider = aws.awsireland

  transit_gateway_id = aws_ec2_transit_gateway.ireland_tgw.id

  tags = {
    Name = "rt-ireland-${var.identifier}"
  }
}

# AWS Transit Gateway attachment associations and propagations
resource "aws_ec2_transit_gateway_route_table_association" "ireland_tgw_association" {
  for_each = module.ireland_spoke_vpcs
  provider = aws.awsireland

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ireland_tgw_rt.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "ireland_tgw_propagation" {
  for_each = module.ireland_spoke_vpcs
  provider = aws.awsireland

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ireland_tgw_rt.id
}

# Core Network peering and TGW RT attachment
resource "aws_networkmanager_transit_gateway_peering" "ireland_peering" {
  provider = aws.awsireland

  core_network_id     = awscc_networkmanager_core_network.core_network.id
  transit_gateway_arn = aws_ec2_transit_gateway.ireland_tgw.arn

  depends_on = [aws_ec2_transit_gateway_policy_table.ireland_policy_table]
}

resource "aws_ec2_transit_gateway_policy_table" "ireland_policy_table" {
  provider = aws.awsireland

  transit_gateway_id = aws_ec2_transit_gateway.ireland_tgw.id

  tags = {
    Name = "tgw-policy-table-ireland-${var.identifier}"
  }
}

resource "aws_ec2_transit_gateway_policy_table_association" "ireland_policy_table_association" {
  provider = aws.awsireland

  transit_gateway_attachment_id   = aws_networkmanager_transit_gateway_peering.ireland_peering.transit_gateway_peering_attachment_id
  transit_gateway_policy_table_id = aws_ec2_transit_gateway_policy_table.ireland_policy_table.id
}

resource "aws_networkmanager_transit_gateway_route_table_attachment" "ireland_tgw_rt_attachment" {
  provider = aws.awsireland

  peering_id                      = aws_networkmanager_transit_gateway_peering.ireland_peering.id
  transit_gateway_route_table_arn = aws_ec2_transit_gateway_route_table.ireland_tgw_rt.arn

  routing_policy_label = "tgwAttachment"

  tags = {
    Name = "ireland-tgw-rt-attachment"
  }
}

# ---------- RESOURCES IN N. VIRGINIA ----------
# AWS Transit Gateway
resource "aws_ec2_transit_gateway" "nvirginia_tgw" {
  provider = aws.awsnvirginia

  description                     = "Transit Gateway - ${var.identifier}"
  amazon_side_asn                 = var.tgw_asn.nvirginia
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name = "tgw-nvirginia-${var.identifier}"
  }
}

# Spoke VPC - definition in variables.tf
module "nvirginia_spoke_vpcs" {
  for_each  = var.nvirginia_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsnvirginia }

  name       = each.key
  cidr_block = each.value.cidr_block
  az_count   = each.value.number_azs

  vpc_assign_generated_ipv6_cidr_block = true

  transit_gateway_id = aws_ec2_transit_gateway.nvirginia_tgw.id
  transit_gateway_routes = {
    workload = "0.0.0.0/0"
  }
  transit_gateway_ipv6_routes = {
    workload = "::/0"
  }

  subnets = {
    endpoints = {
      netmask          = each.value.endpoint_subnet_netmask
      assign_ipv6_cidr = true
    }
    workload = {
      netmask          = each.value.workload_subnet_netmask
      assign_ipv6_cidr = true
    }
    transit_gateway = {
      netmask          = each.value.tgw_subnet_netmask
      assign_ipv6_cidr = true
    }
  }
}

# EC2 Instances (in Spoke VPCs) and EC2 Instance Connect endpoint
module "nvirginia_compute" {
  for_each  = module.nvirginia_spoke_vpcs
  source    = "../../../tf_modules/compute"
  providers = { aws = aws.awsnvirginia }

  identifier      = var.identifier
  vpc_name        = each.key
  vpc             = each.value
  vpc_information = var.nvirginia_spoke_vpcs[each.key]
}

# AWS Transit Gateway route table
resource "aws_ec2_transit_gateway_route_table" "nvirginia_tgw_rt" {
  provider = aws.awsnvirginia

  transit_gateway_id = aws_ec2_transit_gateway.nvirginia_tgw.id

  tags = {
    Name = "rt-nvirginia-${var.identifier}"
  }
}

# AWS Transit Gateway attachment associations and propagations
resource "aws_ec2_transit_gateway_route_table_association" "nvirginia_tgw_association" {
  for_each = module.nvirginia_spoke_vpcs
  provider = aws.awsnvirginia

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.nvirginia_tgw_rt.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "nvirginia_tgw_propagation" {
  for_each = module.nvirginia_spoke_vpcs
  provider = aws.awsnvirginia

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.nvirginia_tgw_rt.id
}

# Core Network peering and TGW RT attachment
resource "aws_networkmanager_transit_gateway_peering" "nvirginia_peering" {
  provider = aws.awsnvirginia

  core_network_id     = awscc_networkmanager_core_network.core_network.id
  transit_gateway_arn = aws_ec2_transit_gateway.nvirginia_tgw.arn

  depends_on = [aws_ec2_transit_gateway_policy_table.nvirginia_policy_table]
}

resource "aws_ec2_transit_gateway_policy_table" "nvirginia_policy_table" {
  provider = aws.awsnvirginia

  transit_gateway_id = aws_ec2_transit_gateway.nvirginia_tgw.id

  tags = {
    Name = "tgw-policy-table-nvirginia-${var.identifier}"
  }
}

resource "aws_ec2_transit_gateway_policy_table_association" "nvirginia_policy_table_association" {
  provider = aws.awsnvirginia

  transit_gateway_attachment_id   = aws_networkmanager_transit_gateway_peering.nvirginia_peering.transit_gateway_peering_attachment_id
  transit_gateway_policy_table_id = aws_ec2_transit_gateway_policy_table.nvirginia_policy_table.id
}

resource "aws_networkmanager_transit_gateway_route_table_attachment" "nvirginia_tgw_rt_attachment" {
  provider = aws.awsnvirginia

  peering_id                      = aws_networkmanager_transit_gateway_peering.nvirginia_peering.id
  transit_gateway_route_table_arn = aws_ec2_transit_gateway_route_table.nvirginia_tgw_rt.arn

  routing_policy_label = "tgwAttachment"

  tags = {
    Name = "nvirginia-tgw-rt-attachment"
  }
}