/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/4-routing_policies/9-inbound_route_filtering/terraform/main.tf ---

data "aws_caller_identity" "current" {}

# ---------- AWS CLOUD WAN RESOURCES ----------
resource "awscc_networkmanager_global_network" "global_network" {
  description = "Global Network - ${var.identifier}"

  tags = [{
    key   = "Name"
    value = "global-network-${var.identifier}"
  }]
}

resource "awscc_networkmanager_core_network" "core_network" {
  global_network_id = awscc_networkmanager_global_network.global_network.id
  description       = "Core Network - ${var.identifier}"
  policy_document   = file("${path.module}/cloudwan_policy.json")

  tags = [{
    key   = "Name"
    value = "core-network-${var.identifier}"
  }]
}

# ---------- SPOKE VPCs ----------
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
    workload = { netmask = each.value.workload_subnet_netmask }
    core_network = {
      netmask            = each.value.cnetwork_subnet_netmask
      require_acceptance = false

      tags = {
        segment = each.value.segment
      }
    }
  }
}

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
    workload = { netmask = each.value.workload_subnet_netmask }
    core_network = {
      netmask            = each.value.cnetwork_subnet_netmask
      require_acceptance = false

      tags = {
        segment = each.value.segment
      }
    }
  }
}

# ---------- HYBRID CONNECTIVITY (DX Gateway) ----------
resource "aws_dx_gateway" "dxgw" {
  provider = aws.awsnvirginia

  name            = "dxgw-${var.identifier}"
  amazon_side_asn = var.dx_gateway_asn
}

resource "aws_networkmanager_dx_gateway_attachment" "hybrid" {
  provider = aws.awsnvirginia

  core_network_id            = awscc_networkmanager_core_network.core_network.core_network_id
  direct_connect_gateway_arn = "arn:aws:directconnect::${data.aws_caller_identity.current.account_id}:dx-gateway/${aws_dx_gateway.dxgw.id}"
  edge_locations             = values(var.aws_regions)

  tags = {
    segment              = "hybrid"
    routing-policy-label = "hybridRouteFiltering"
  }
}

# ---------- PREFIX LIST (dangerous routes to drop) ----------
resource "aws_ec2_managed_prefix_list" "dangerous_prefixes" {
  provider = aws.awsnvirginia

  name           = "dangerous-prefixes-${var.identifier}"
  address_family = "IPv4"
  max_entries    = 10

  # Drop default route from on-prem (prevents route leak)
  entry {
    cidr        = "0.0.0.0/0"
    description = "Block default route from on-premises"
  }

  # Drop prefix that overlaps with production VPC CIDR
  entry {
    cidr        = "10.0.0.0/16"
    description = "Block overlap with prod-us-east-1 VPC CIDR"
  }

  # Drop RFC1918 supernet that would attract all private traffic
  entry {
    cidr        = "10.0.0.0/8"
    description = "Block broad supernet from on-premises"
  }

  tags = {
    Name = "dangerous-prefixes-${var.identifier}"
  }
}

# NOTE: Prefix list association with Core Network requires AWS CLI:
# aws networkmanager create-core-network-prefix-list-association \
#   --core-network-id <core-network-id> \
#   --prefix-list-arn <prefix-list-arn> \
#   --prefix-list-alias "dangerousPrefixes" \
#   --region us-east-1
