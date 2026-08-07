/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/1-basic/terraform/main.tf ---

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
# Spoke VPCs - definition in variables.tf
module "nvirginia_spoke_vpcs" {
  for_each  = var.nvirginia_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsnvirginia }

  name       = "${each.key}-${var.aws_regions.nvirginia}-${var.identifier}"
  cidr_block = each.value.cidr_block
  az_count   = each.value.number_azs

  core_network = {
    id  = awscc_networkmanager_core_network.core_network.core_network_id
    arn = awscc_networkmanager_core_network.core_network.core_network_arn
  }
  core_network_routes = {
    workload = "0.0.0.0/0"
  }

  subnets = {
    endpoints = { netmask = each.value.endpoint_subnet_netmask }
    workload  = { netmask = each.value.workload_subnet_netmask }
    core_network = {
      netmask            = each.value.cnetwork_subnet_netmask
      require_acceptance = false

      tags = { domain = each.value.segment }
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
# Spoke VPCs - definition in variables.tf
module "ireland_spoke_vpcs" {
  for_each  = var.ireland_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsireland }

  name       = "${each.key}-${var.aws_regions.ireland}-${var.identifier}"
  cidr_block = each.value.cidr_block
  az_count   = each.value.number_azs

  core_network = {
    id  = awscc_networkmanager_core_network.core_network.core_network_id
    arn = awscc_networkmanager_core_network.core_network.core_network_arn
  }
  core_network_routes = {
    workload = "0.0.0.0/0"
  }

  subnets = {
    endpoints = { netmask = each.value.endpoint_subnet_netmask }
    workload  = { netmask = each.value.workload_subnet_netmask }
    core_network = {
      netmask            = each.value.cnetwork_subnet_netmask
      require_acceptance = false

      tags = { domain = each.value.segment }
    }
  }
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
