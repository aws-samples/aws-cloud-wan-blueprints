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
# Transit Gateway
resource "aws_ec2_transit_gateway" "nvirginia_transit_gateway" {
  provider = aws.awsnvirginia

  amazon_side_asn                 = var.transit_gateway_asns.nvirginia
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  description                     = "Transit Gateway - ${var.aws_regions.nvirginia}"

  tags = {
    Name = "tgw-${var.aws_regions.nvirginia}-${var.identifier}"
  }
}

# Transit Gateway route tables
resource "aws_ec2_transit_gateway_route_table" "nvirginia_tgw_production_rt" {
  provider = aws.awsnvirginia

  transit_gateway_id = aws_ec2_transit_gateway.nvirginia_transit_gateway.id

  tags = {
    Name = "tgw-rt-production-${var.aws_regions.nvirginia}-${var.identifier}"
  }
}

resource "aws_ec2_transit_gateway_route_table" "nvirginia_tgw_development_rt" {
  provider = aws.awsnvirginia

  transit_gateway_id = aws_ec2_transit_gateway.nvirginia_transit_gateway.id

  tags = {
    Name = "tgw-rt-development-${var.aws_regions.nvirginia}-${var.identifier}"
  }
}

# Spoke VPCs (attached to Transit Gateway)
module "nvirginia_spoke_vpcs" {
  for_each  = var.nvirginia_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsnvirginia }

  name       = "${each.key}-${var.aws_regions.nvirginia}-${var.identifier}"
  cidr_block = each.value.cidr_block
  az_count   = each.value.number_azs

  transit_gateway_id = aws_ec2_transit_gateway.nvirginia_transit_gateway.id
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

# Associate each spoke VPC attachment with the route table it belongs to
resource "aws_ec2_transit_gateway_route_table_association" "nvirginia_tgw_association" {
  for_each = module.nvirginia_spoke_vpcs
  provider = aws.awsnvirginia

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = var.nvirginia_spoke_vpcs[each.key].segment == "production" ? aws_ec2_transit_gateway_route_table.nvirginia_tgw_production_rt.id : aws_ec2_transit_gateway_route_table.nvirginia_tgw_development_rt.id
}

# Propagate each spoke VPC's routes into the same route table
resource "aws_ec2_transit_gateway_route_table_propagation" "nvirginia_tgw_propagation" {
  for_each = module.nvirginia_spoke_vpcs
  provider = aws.awsnvirginia

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = var.nvirginia_spoke_vpcs[each.key].segment == "production" ? aws_ec2_transit_gateway_route_table.nvirginia_tgw_production_rt.id : aws_ec2_transit_gateway_route_table.nvirginia_tgw_development_rt.id
}

# Cloud WAN peering
resource "aws_networkmanager_transit_gateway_peering" "nvirginia_tgw_cwan_peering" {
  provider = aws.awsnvirginia

  core_network_id     = awscc_networkmanager_core_network.core_network.core_network_id
  transit_gateway_arn = aws_ec2_transit_gateway.nvirginia_transit_gateway.arn

  tags = {
    Name = "tgw-cwan-peering-${var.aws_regions.nvirginia}-${var.identifier}"
  }
}

# Transit gateway policy table
resource "aws_ec2_transit_gateway_policy_table" "nvirginia_tgw_policy_table" {
  provider = aws.awsnvirginia

  transit_gateway_id = aws_ec2_transit_gateway.nvirginia_transit_gateway.id

  tags = {
    Name = "tgw-policy-table-${var.aws_regions.nvirginia}-${var.identifier}"
  }
}

resource "aws_ec2_transit_gateway_policy_table_association" "nvirginia_tgw_policy_table_assoc" {
  provider = aws.awsnvirginia

  transit_gateway_attachment_id   = aws_networkmanager_transit_gateway_peering.nvirginia_tgw_cwan_peering.transit_gateway_peering_attachment_id
  transit_gateway_policy_table_id = aws_ec2_transit_gateway_policy_table.nvirginia_tgw_policy_table.id
}

# Cloud WAN Transit Gateway route table attachment
resource "aws_networkmanager_transit_gateway_route_table_attachment" "nvirginia_production_rt_attachment" {
  provider = aws.awsnvirginia

  peering_id                      = aws_networkmanager_transit_gateway_peering.nvirginia_tgw_cwan_peering.id
  transit_gateway_route_table_arn = aws_ec2_transit_gateway_route_table.nvirginia_tgw_production_rt.arn

  tags = {
    Name   = "tgw-rt-attachment-production-${var.aws_regions.nvirginia}-${var.identifier}"
    domain = "production"
  }

  depends_on = [
    aws_ec2_transit_gateway_policy_table_association.nvirginia_tgw_policy_table_assoc
  ]
}

resource "aws_networkmanager_transit_gateway_route_table_attachment" "nvirginia_development_rt_attachment" {
  provider = aws.awsnvirginia

  peering_id                      = aws_networkmanager_transit_gateway_peering.nvirginia_tgw_cwan_peering.id
  transit_gateway_route_table_arn = aws_ec2_transit_gateway_route_table.nvirginia_tgw_development_rt.arn

  tags = {
    Name   = "tgw-rt-attachment-development-${var.aws_regions.nvirginia}-${var.identifier}"
    domain = "development"
  }

  depends_on = [
    aws_ec2_transit_gateway_policy_table_association.nvirginia_tgw_policy_table_assoc
  ]
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
# Transit Gateway
resource "aws_ec2_transit_gateway" "ireland_transit_gateway" {
  provider = aws.awsireland

  amazon_side_asn                 = var.transit_gateway_asns.ireland
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  description                     = "Transit Gateway - ${var.aws_regions.ireland}"

  tags = {
    Name = "tgw-${var.aws_regions.ireland}-${var.identifier}"
  }
}

# Transit Gateway route tables
resource "aws_ec2_transit_gateway_route_table" "ireland_tgw_production_rt" {
  provider = aws.awsireland

  transit_gateway_id = aws_ec2_transit_gateway.ireland_transit_gateway.id

  tags = {
    Name = "tgw-rt-production-${var.aws_regions.ireland}-${var.identifier}"
  }
}

resource "aws_ec2_transit_gateway_route_table" "ireland_tgw_development_rt" {
  provider = aws.awsireland

  transit_gateway_id = aws_ec2_transit_gateway.ireland_transit_gateway.id

  tags = {
    Name = "tgw-rt-development-${var.aws_regions.ireland}-${var.identifier}"
  }
}

# Spoke VPCs (attached to Transit Gateway)
module "ireland_spoke_vpcs" {
  for_each  = var.ireland_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsireland }

  name       = "${each.key}-${var.aws_regions.ireland}-${var.identifier}"
  cidr_block = each.value.cidr_block
  az_count   = each.value.number_azs

  transit_gateway_id = aws_ec2_transit_gateway.ireland_transit_gateway.id
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

# Associate each spoke VPC attachment with the route table it belongs to
resource "aws_ec2_transit_gateway_route_table_association" "ireland_tgw_association" {
  for_each = module.ireland_spoke_vpcs
  provider = aws.awsireland

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = var.ireland_spoke_vpcs[each.key].segment == "production" ? aws_ec2_transit_gateway_route_table.ireland_tgw_production_rt.id : aws_ec2_transit_gateway_route_table.ireland_tgw_development_rt.id
}

# Propagate each spoke VPC's routes into the same route table
resource "aws_ec2_transit_gateway_route_table_propagation" "ireland_tgw_propagation" {
  for_each = module.ireland_spoke_vpcs
  provider = aws.awsireland

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = var.ireland_spoke_vpcs[each.key].segment == "production" ? aws_ec2_transit_gateway_route_table.ireland_tgw_production_rt.id : aws_ec2_transit_gateway_route_table.ireland_tgw_development_rt.id
}

# Cloud WAN peering
resource "aws_networkmanager_transit_gateway_peering" "ireland_tgw_cwan_peering" {
  provider = aws.awsireland

  core_network_id     = awscc_networkmanager_core_network.core_network.core_network_id
  transit_gateway_arn = aws_ec2_transit_gateway.ireland_transit_gateway.arn

  tags = {
    Name = "tgw-cwan-peering-${var.aws_regions.ireland}-${var.identifier}"
  }
}

# Transit gateway policy table
resource "aws_ec2_transit_gateway_policy_table" "ireland_tgw_policy_table" {
  provider = aws.awsireland

  transit_gateway_id = aws_ec2_transit_gateway.ireland_transit_gateway.id

  tags = {
    Name = "tgw-policy-table-${var.aws_regions.ireland}-${var.identifier}"
  }
}

resource "aws_ec2_transit_gateway_policy_table_association" "ireland_tgw_policy_table_assoc" {
  provider = aws.awsireland

  transit_gateway_attachment_id   = aws_networkmanager_transit_gateway_peering.ireland_tgw_cwan_peering.transit_gateway_peering_attachment_id
  transit_gateway_policy_table_id = aws_ec2_transit_gateway_policy_table.ireland_tgw_policy_table.id
}

# Cloud WAN Transit Gateway route table attachment
resource "aws_networkmanager_transit_gateway_route_table_attachment" "ireland_production_rt_attachment" {
  provider = aws.awsireland

  peering_id                      = aws_networkmanager_transit_gateway_peering.ireland_tgw_cwan_peering.id
  transit_gateway_route_table_arn = aws_ec2_transit_gateway_route_table.ireland_tgw_production_rt.arn

  tags = {
    Name   = "tgw-rt-attachment-production-${var.aws_regions.ireland}-${var.identifier}"
    domain = "production"
  }

  depends_on = [
    aws_ec2_transit_gateway_policy_table_association.ireland_tgw_policy_table_assoc
  ]
}

resource "aws_networkmanager_transit_gateway_route_table_attachment" "ireland_development_rt_attachment" {
  provider = aws.awsireland

  peering_id                      = aws_networkmanager_transit_gateway_peering.ireland_tgw_cwan_peering.id
  transit_gateway_route_table_arn = aws_ec2_transit_gateway_route_table.ireland_tgw_development_rt.arn

  tags = {
    Name   = "tgw-rt-attachment-development-${var.aws_regions.ireland}-${var.identifier}"
    domain = "development"
  }

  depends_on = [
    aws_ec2_transit_gateway_policy_table_association.ireland_tgw_policy_table_assoc
  ]
}

# EC2 instances (in the spoke VPCs) and an EC2 Instance Connect endpoint
module "ireland_compute" {
  for_each  = module.ireland_spoke_vpcs
  source    = "../../tf_modules/compute"
  providers = { aws = aws.awsireland }

  identifier      = var.identifier
  vpc_name        = "${each.key}-${var.aws_regions.ireland}"
  vpc             = each.value
  vpc_information = var.ireland_spoke_vpcs[each.key]
}
