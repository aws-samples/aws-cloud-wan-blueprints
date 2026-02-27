/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/4-advanced_routing/3-inspection_after_filtering/terraform/main.tf ---

# ---------- AWS CLOUD WAN RESOURCES ----------
# Global Network
resource "awscc_networkmanager_global_network" "global_network" {
  description = "Global Network - ${var.identifier}"

  tags = [{
    key   = "Name"
    value = "global-network-${var.identifier}"
  }]
}

# Core Network
resource "awscc_networkmanager_core_network" "core_network" {
  global_network_id = awscc_networkmanager_global_network.global_network.id
  description       = "Core Network - ${var.identifier}"

  policy_document = data.aws_networkmanager_core_network_policy_document.policy_document.json

  tags = [{
    key   = "Name"
    value = "core-network-${var.identifier}"
  }]
}

# ---------- RESOURCES IN IRELAND ----------
# Spoke VPCs - definition in variables.tf
module "ireland_spoke_vpcs" {
  for_each  = var.ireland_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsireland }

  name       = each.key
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
      netmask = each.value.cnetwork_subnet_netmask

      tags = { domain = each.value.segment }
    }
  }
}

resource "aws_networkmanager_attachment_routing_policy_label" "ireland_routing_policy_label" {
  for_each = var.ireland_spoke_vpcs
  provider = aws.awsireland

  core_network_id      = awscc_networkmanager_core_network.core_network.core_network_id
  attachment_id        = module.ireland_spoke_vpcs[each.key].core_network_attachment.id
  routing_policy_label = "vpcAttachments"

  depends_on = [module.ireland_spoke_vpcs]
}

module "ireland_secondary_cidr_blocks" {
  for_each  = var.ireland_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsireland }

  name               = "${each.key}-secondary-cidr"
  vpc_id             = module.ireland_spoke_vpcs[each.key].vpc_attributes.id
  create_vpc         = false
  vpc_secondary_cidr = true

  cidr_block = "100.64.0.0/16"
  az_count   = each.value.number_azs

  subnets = {
    private_secondary_cidr = { netmask = 28 }
  }
}

# Inspection VPC - definition in variables.tf
module "ireland_inspection_vpc" {
  source    = "aws-ia/cloudwan/aws"
  version   = "3.4.0"
  providers = { aws = aws.awsireland }

  core_network_arn = awscc_networkmanager_core_network.core_network.core_network_arn

  central_vpcs = {
    inspection = {
      type       = "inspection"
      name       = "inspection-vpc-ireland"
      cidr_block = var.inspection_vpc.cidr_block
      az_count   = var.inspection_vpc.number_azs

      subnets = {
        endpoints = { netmask = var.inspection_vpc.inspection_subnet_netmask }
        core_network = {
          netmask = var.inspection_vpc.cnetwork_subnet_netmask

          tags = { inspection = "true" }
        }
      }
    }
  }

  aws_network_firewall = {
    inspection = {
      name        = "anfw-ireland"
      description = "AWS Network Firewall - eu-west-1"
      policy_arn  = module.ireland_anfw_policy.policy_arn
    }
  }
}

# AWS Network Firewall policy
module "ireland_anfw_policy" {
  source    = "../../../tf_modules/firewall_policy"
  providers = { aws = aws.awsireland }

  identifier   = var.identifier
  traffic_flow = "east-west"
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

# ---------- RESOURCES IN N. VIRGINIA ----------
# Spoke VPCs - definition in variables.tf
module "nvirginia_spoke_vpcs" {
  for_each  = var.nvirginia_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsnvirginia }

  name       = each.key
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
      netmask = each.value.cnetwork_subnet_netmask

      tags = { domain = each.value.segment }
    }
  }
}

resource "aws_networkmanager_attachment_routing_policy_label" "nvirginia_routing_policy_label" {
  for_each = var.nvirginia_spoke_vpcs
  provider = aws.awsnvirginia

  core_network_id      = awscc_networkmanager_core_network.core_network.core_network_id
  attachment_id        = module.nvirginia_spoke_vpcs[each.key].core_network_attachment.id
  routing_policy_label = "vpcAttachments"

  depends_on = [module.ireland_spoke_vpcs]
}

module "nvirginia_secondary_cidr_blocks" {
  for_each  = var.nvirginia_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awsnvirginia }

  name               = "${each.key}-secondary-cidr"
  vpc_id             = module.nvirginia_spoke_vpcs[each.key].vpc_attributes.id
  create_vpc         = false
  vpc_secondary_cidr = true

  cidr_block = "100.64.0.0/16"
  az_count   = each.value.number_azs

  subnets = {
    private_secondary_cidr = { netmask = 28 }
  }
}

# Inspection VPC - definition in variables.tf
module "nvirginia_inspection_vpc" {
  source    = "aws-ia/cloudwan/aws"
  version   = "3.4.0"
  providers = { aws = aws.awsnvirginia }

  core_network_arn = awscc_networkmanager_core_network.core_network.core_network_arn

  central_vpcs = {
    inspection = {
      type       = "inspection"
      name       = "inspection-vpc-nvirginia"
      cidr_block = var.inspection_vpc.cidr_block
      az_count   = var.inspection_vpc.number_azs

      subnets = {
        endpoints = { netmask = var.inspection_vpc.inspection_subnet_netmask }
        core_network = {
          netmask = var.inspection_vpc.cnetwork_subnet_netmask

          tags = { inspection = "true" }
        }
      }
    }
  }

  aws_network_firewall = {
    inspection = {
      name        = "anfw-nvirginia"
      description = "AWS Network Firewall - us-east-1"
      policy_arn  = module.nvirginia_anfw_policy.policy_arn
    }
  }
}

# AWS Network Firewall policy
module "nvirginia_anfw_policy" {
  source    = "../../../tf_modules/firewall_policy"
  providers = { aws = aws.awsnvirginia }

  identifier   = var.identifier
  traffic_flow = "east-west"
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