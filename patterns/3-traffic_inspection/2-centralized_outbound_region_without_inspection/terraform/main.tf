/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- centralized_outbound_region_without_inspection/main.tf ---

# ---------- AWS CLOUD WAN RESOURCES ----------
# Global Network
resource "awscc_networkmanager_global_network" "global_network" {
  provider = awscc.awsccnvirginia

  description = "Global Network - ${var.identifier}"

  tags = [{
    key   = "Name"
    value = "Global Network - ${var.identifier}"
  }]
}

# Core Network
resource "awscc_networkmanager_core_network" "core_network" {
  provider = awscc.awsccnvirginia

  global_network_id = awscc_networkmanager_global_network.global_network.id
  description       = "Core Network - ${var.identifier}"
  policy_document   = data.aws_networkmanager_core_network_policy_document.policy.json

  tags = [{
    key   = "Name"
    value = "Core Network - ${var.identifier}"
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
      netmask            = each.value.cnetwork_subnet_netmask
      require_acceptance = false

      tags = {
        domain = each.value.segment
      }
    }
  }
}

# Inspection VPC - definition in variables.tf
module "ireland_inspection_vpc" {
  source    = "aws-ia/cloudwan/aws"
  version   = "3.4.0"
  providers = { aws = aws.awsireland }

  core_network_arn = awscc_networkmanager_core_network.core_network.core_network_arn

  ipv4_network_definition = "10.0.0.0/8"
  central_vpcs = {
    inspection = {
      type       = "egress_with_inspection"
      name       = var.ireland_inspection_vpc.name
      cidr_block = var.ireland_inspection_vpc.cidr_block
      az_count   = var.ireland_inspection_vpc.number_azs

      subnets = {
        public    = { netmask = var.ireland_inspection_vpc.public_subnet_netmask }
        endpoints = { netmask = var.ireland_inspection_vpc.inspection_subnet_netmask }
        core_network = {
          netmask = var.ireland_inspection_vpc.cnetwork_subnet_netmask

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
  traffic_flow = "north-south"
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
      netmask            = each.value.cnetwork_subnet_netmask
      require_acceptance = false

      tags = {
        domain = each.value.segment
      }
    }
  }
}

# Inspection VPC - definition in variables.tf
module "nvirginia_inspection_vpc" {
  source    = "aws-ia/cloudwan/aws"
  version   = "3.4.0"
  providers = { aws = aws.awsnvirginia }

  core_network_arn = awscc_networkmanager_core_network.core_network.core_network_arn

  ipv4_network_definition = "10.0.0.0/8"
  central_vpcs = {
    inspection = {
      type       = "egress_with_inspection"
      name       = var.nvirginia_inspection_vpc.name
      cidr_block = var.nvirginia_inspection_vpc.cidr_block
      az_count   = var.nvirginia_inspection_vpc.number_azs

      subnets = {
        public    = { netmask = var.nvirginia_inspection_vpc.public_subnet_netmask }
        endpoints = { netmask = var.nvirginia_inspection_vpc.inspection_subnet_netmask }
        core_network = {
          netmask = var.nvirginia_inspection_vpc.cnetwork_subnet_netmask

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
  traffic_flow = "north-south"
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

# ---------- RESOURCES IN SYDNEY ----------
# Spoke VPCs - definition in variables.tf
module "sydney_spoke_vpcs" {
  for_each  = var.sydney_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awssydney }

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
      netmask            = each.value.cnetwork_subnet_netmask
      require_acceptance = false

      tags = {
        domain = each.value.segment
      }
    }
  }
}

# Inspection VPC - definition in variables.tf
module "sydney_inspection_vpc" {
  source    = "aws-ia/cloudwan/aws"
  version   = "3.4.0"
  providers = { aws = aws.awssydney }

  core_network_arn = awscc_networkmanager_core_network.core_network.core_network_arn

  ipv4_network_definition = "10.0.0.0/8"
  central_vpcs = {
    inspection = {
      type       = "egress_with_inspection"
      name       = var.sydney_inspection_vpc.name
      cidr_block = var.sydney_inspection_vpc.cidr_block
      az_count   = var.sydney_inspection_vpc.number_azs

      subnets = {
        public    = { netmask = var.sydney_inspection_vpc.public_subnet_netmask }
        endpoints = { netmask = var.sydney_inspection_vpc.inspection_subnet_netmask }
        core_network = {
          netmask = var.sydney_inspection_vpc.cnetwork_subnet_netmask

          tags = { inspection = "true" }
        }
      }
    }
  }

  aws_network_firewall = {
    inspection = {
      name        = "anfw-sydney"
      description = "AWS Network Firewall - ap-southeast-2"
      policy_arn  = module.sydney_anfw_policy.policy_arn
    }
  }
}

# AWS Network Firewall policy
module "sydney_anfw_policy" {
  source    = "../../../tf_modules/firewall_policy"
  providers = { aws = aws.awssydney }

  identifier   = var.identifier
  traffic_flow = "north-south"
}

# EC2 Instances (in Spoke VPCs) and EC2 Instance Connect endpoint
module "sydney_compute" {
  for_each  = module.sydney_spoke_vpcs
  source    = "../../../tf_modules/compute"
  providers = { aws = aws.awssydney }

  identifier      = var.identifier
  vpc_name        = each.key
  vpc             = each.value
  vpc_information = var.sydney_spoke_vpcs[each.key]
}

# ---------- RESOURCES IN LONDON (ONLY SPOKE VPCS) ----------
# Spoke VPCs - definition in variables.tf
module "london_spoke_vpcs" {
  for_each  = var.london_spoke_vpcs
  source    = "aws-ia/vpc/aws"
  version   = "= 4.7.3"
  providers = { aws = aws.awslondon }

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
      netmask            = each.value.cnetwork_subnet_netmask
      require_acceptance = false

      tags = {
        domain = each.value.segment
      }
    }
  }
}

# EC2 Instances (in Spoke VPCs) and EC2 Instance Connect endpoint
module "london_compute" {
  for_each  = module.london_spoke_vpcs
  source    = "../../../tf_modules/compute"
  providers = { aws = aws.awslondon }

  identifier      = var.identifier
  vpc_name        = each.key
  vpc             = each.value
  vpc_information = var.london_spoke_vpcs[each.key]
}
