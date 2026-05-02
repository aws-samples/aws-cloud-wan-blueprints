/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/4-advanced_routing/7-summarization/terraform/main.tf ---

# ---------- AWS CLOUD WAN RESOURCES ----------
# Global Network
resource "aws_networkmanager_global_network" "global_network" {
  provider = aws.awsnvirginia

  description = "Global Network - ${var.identifier}"

  tags = {
    Name = "global-network-${var.identifier}"
  }
}

resource "aws_networkmanager_core_network" "core_network" {
  provider = aws.awsnvirginia

  global_network_id = aws_networkmanager_global_network.global_network.id
  description       = "Core Network - ${var.identifier}"

  create_base_policy   = true
  base_policy_document = data.aws_networkmanager_core_network_policy_document.base_policy_document.json

  tags = {
    Name = "core-network-${var.identifier}"
  }
}

resource "aws_networkmanager_core_network_policy_attachment" "core_network_policy_attachment" {
  provider = aws.awsnvirginia

  core_network_id = aws_networkmanager_core_network.core_network.id
  policy_document = data.aws_networkmanager_core_network_policy_document.policy_document.json

  depends_on = [
    aws_networkmanager_prefix_list_association.nvirginia_prefix_list_association,
    aws_networkmanager_prefix_list_association.ireland_prefix_list_association
  ]
}

# Prefix List association
resource "aws_networkmanager_prefix_list_association" "nvirginia_prefix_list_association" {
  provider = aws.awsoregon

  core_network_id   = aws_networkmanager_core_network.core_network.id
  prefix_list_arn   = aws_ec2_managed_prefix_list.nvirginia_ipv4_cidr_blocks.arn
  prefix_list_alias = "nvirginiaipv4routes"

  depends_on = [module.ireland_spoke_vpcs, module.nvirginia_spoke_vpcs]
}

resource "aws_networkmanager_prefix_list_association" "ireland_prefix_list_association" {
  provider = aws.awsoregon

  core_network_id   = aws_networkmanager_core_network.core_network.id
  prefix_list_arn   = aws_ec2_managed_prefix_list.ireland_ipv4_cidr_blocks.arn
  prefix_list_alias = "irelandipv4routes"

  depends_on = [module.ireland_spoke_vpcs, module.nvirginia_spoke_vpcs]
}

# ---------- PREFIX LIST (Oregon) ----------
resource "aws_ec2_managed_prefix_list" "nvirginia_ipv4_cidr_blocks" {
  provider = aws.awsoregon

  name           = "IPv4 CIDR blocks (N. Virginia) - ${var.identifier}"
  address_family = "IPv4"
  max_entries    = length(var.nvirginia_spoke_vpcs)
}

resource "aws_ec2_managed_prefix_list_entry" "nvirginia_cidr_blocks" {
  for_each = var.nvirginia_spoke_vpcs
  provider = aws.awsoregon

  cidr           = each.value.cidr_block
  description    = each.key
  prefix_list_id = aws_ec2_managed_prefix_list.nvirginia_ipv4_cidr_blocks.id
}

resource "aws_ec2_managed_prefix_list" "ireland_ipv4_cidr_blocks" {
  provider = aws.awsoregon

  name           = "IPv4 CIDR blocks (Ireland) - ${var.identifier}"
  address_family = "IPv4"
  max_entries    = length(var.ireland_spoke_vpcs)
}

resource "aws_ec2_managed_prefix_list_entry" "ireland_cidr_blocks" {
  for_each = var.ireland_spoke_vpcs
  provider = aws.awsoregon

  cidr           = each.value.cidr_block
  description    = each.key
  prefix_list_id = aws_ec2_managed_prefix_list.ireland_ipv4_cidr_blocks.id
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

  vpc_assign_generated_ipv6_cidr_block = true

  core_network = {
    id  = aws_networkmanager_core_network.core_network.id
    arn = aws_networkmanager_core_network.core_network.arn
  }
  core_network_routes = {
    workload = "0.0.0.0/0"
  }
  core_network_ipv6_routes = {
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
    core_network = {
      netmask          = each.value.cnetwork_subnet_netmask
      assign_ipv6_cidr = true

      tags = { domain = each.value.segment }
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

  vpc_assign_generated_ipv6_cidr_block = true

  core_network = {
    id  = aws_networkmanager_core_network.core_network.id
    arn = aws_networkmanager_core_network.core_network.arn
  }
  core_network_routes = {
    workload = "0.0.0.0/0"
  }
  core_network_ipv6_routes = {
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
    core_network = {
      netmask          = each.value.cnetwork_subnet_netmask
      assign_ipv6_cidr = true

      tags = { domain = each.value.segment }
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
