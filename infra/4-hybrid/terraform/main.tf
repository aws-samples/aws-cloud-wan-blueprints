/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/4-hybrid/terraform/main.tf ---

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

# ---------- HYBRID: SITE-TO-SITE VPN ----------
# Optional. Deployable with no on-premises equipment - a customer gateway is only an IP
# and an ASN - so the attachment exists and associates to the `hybrid` segment by
# ATTACHMENT TYPE. The tunnels stay DOWN until a real peer answers, so no routes are
# exchanged: use this to observe association and policy labels, not data plane.
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

resource "aws_networkmanager_site_to_site_vpn_attachment" "vpn_attachment" {
  count = var.site_to_site_vpn != null ? 1 : 0

  core_network_id    = awscc_networkmanager_core_network.core_network.core_network_id
  vpn_connection_arn = aws_vpn_connection.vpn[0].arn

  tags = {
    Name = "vpn-attachment-${var.identifier}"
  }
}

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
# Optional. The gateway and its Cloud WAN attachment deploy with no circuit; passing
# traffic needs a real Direct Connect connection and a virtual interface associated with
# the gateway, which cannot be simulated.
#
# A Direct Connect gateway attaches to EVERY Core Network Edge. That is why route
# summarization for a DXGW needs a per-Region supernet rather than one aggregate - see
# policy/6-routing_policies.md.
resource "aws_dx_gateway" "dxgw" {
  count    = var.direct_connect_gateway != null ? 1 : 0
  provider = aws.awsnvirginia

  name            = "dxgw-${var.identifier}"
  amazon_side_asn = var.direct_connect_gateway.amazon_side_asn
}

resource "aws_networkmanager_dx_gateway_attachment" "dxgw_attachment" {
  count = var.direct_connect_gateway != null ? 1 : 0

  core_network_id            = awscc_networkmanager_core_network.core_network.core_network_id
  direct_connect_gateway_arn = "arn:aws:directconnect::${data.aws_caller_identity.current.account_id}:dx-gateway/${aws_dx_gateway.dxgw[0].id}"
  edge_locations             = [var.aws_regions.nvirginia, var.aws_regions.ireland]

  tags = {
    Name = "dxgw-attachment-${var.identifier}"
  }
}

data "aws_caller_identity" "current" {
  provider = aws.awsnvirginia
}

# ---------- HYBRID: CONNECT (SD-WAN) ----------
# Optional. A Connect attachment rides on top of an existing VPC attachment (the
# transport attachment) and needs `inside-cidr-blocks` in the policy document. The peer
# is created only when an appliance address is supplied.
resource "aws_networkmanager_connect_attachment" "connect_attachment" {
  count = var.connect != null ? 1 : 0

  core_network_id         = awscc_networkmanager_core_network.core_network.core_network_id
  transport_attachment_id = module.nvirginia_spoke_vpcs[var.connect.transport_vpc].core_network_attachment.id
  edge_location           = var.connect.region

  options {
    protocol = var.connect.protocol
  }

  tags = {
    Name = "connect-attachment-${var.identifier}"
  }
}

resource "aws_networkmanager_connect_peer" "connect_peer" {
  count = var.connect != null && try(var.connect.peer_address, null) != null ? 1 : 0

  connect_attachment_id = aws_networkmanager_connect_attachment.connect_attachment[0].id
  peer_address          = var.connect.peer_address

  bgp_options {
    peer_asn = var.connect.peer_asn
  }

  tags = {
    Name = "connect-peer-${var.identifier}"
  }
}

# ---------- RESOURCES IN N. VIRGINIA ----------
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

      # Attachment tagging contract (infra/README.md): `domain` names the segment.
      # Hybrid attachments deliberately carry NO tag - they are matched on
      # attachment-type instead. See policy/3-attachment_policies.md.
      tags = { domain = each.value.segment }
    }
  }
}

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

module "ireland_compute" {
  for_each  = module.ireland_spoke_vpcs
  source    = "../../tf_modules/compute"
  providers = { aws = aws.awsireland }

  identifier      = var.identifier
  vpc_name        = "${each.key}-${var.aws_regions.ireland}"
  vpc             = each.value
  vpc_information = var.ireland_spoke_vpcs[each.key]
}

# ---------- PREFIX LISTS FOR ROUTE SUMMARIZATION (HOME REGION) ----------
# Managed prefix lists MUST be created in Cloud WAN's home Region (us-west-2) to be
# associated with a core network, regardless of where the edge locations are. A
# summarization routing policy matches on the ALIAS, not on the prefix list ID - see
# policy/6-routing_policies.md.
#
# One list per Region, because a Direct Connect gateway attaches to every Core Network
# Edge: advertising a single aggregate from every edge would make on-premises see
# equal-cost paths into any Region.
resource "aws_ec2_managed_prefix_list" "nvirginia_ipv4" {
  count    = var.create_prefix_lists ? 1 : 0
  provider = aws.awshome

  name           = "ipv4-${var.aws_regions.nvirginia}-${var.identifier}"
  address_family = "IPv4"
  max_entries    = length(var.nvirginia_spoke_vpcs)

  tags = {
    Name = "ipv4-${var.aws_regions.nvirginia}-${var.identifier}"
  }
}

resource "aws_ec2_managed_prefix_list_entry" "nvirginia_ipv4_entries" {
  for_each = var.create_prefix_lists ? var.nvirginia_spoke_vpcs : {}
  provider = aws.awshome

  cidr           = each.value.cidr_block
  description    = "${each.key} (${var.aws_regions.nvirginia})"
  prefix_list_id = aws_ec2_managed_prefix_list.nvirginia_ipv4[0].id
}

resource "aws_ec2_managed_prefix_list" "ireland_ipv4" {
  count    = var.create_prefix_lists ? 1 : 0
  provider = aws.awshome

  name           = "ipv4-${var.aws_regions.ireland}-${var.identifier}"
  address_family = "IPv4"
  max_entries    = length(var.ireland_spoke_vpcs)

  tags = {
    Name = "ipv4-${var.aws_regions.ireland}-${var.identifier}"
  }
}

resource "aws_ec2_managed_prefix_list_entry" "ireland_ipv4_entries" {
  for_each = var.create_prefix_lists ? var.ireland_spoke_vpcs : {}
  provider = aws.awshome

  cidr           = each.value.cidr_block
  description    = "${each.key} (${var.aws_regions.ireland})"
  prefix_list_id = aws_ec2_managed_prefix_list.ireland_ipv4[0].id
}

# Associate each prefix list with the core network under the alias a routing policy
# matches on with `prefix-in-prefix-list`.
resource "aws_networkmanager_prefix_list_association" "nvirginia" {
  count    = var.create_prefix_lists ? 1 : 0
  provider = aws.awshome

  core_network_id   = awscc_networkmanager_core_network.core_network.core_network_id
  prefix_list_arn   = aws_ec2_managed_prefix_list.nvirginia_ipv4[0].arn
  prefix_list_alias = "nvirginiaipv4routes"

  depends_on = [module.nvirginia_spoke_vpcs, module.ireland_spoke_vpcs]
}

resource "aws_networkmanager_prefix_list_association" "ireland" {
  count    = var.create_prefix_lists ? 1 : 0
  provider = aws.awshome

  core_network_id   = awscc_networkmanager_core_network.core_network.core_network_id
  prefix_list_arn   = aws_ec2_managed_prefix_list.ireland_ipv4[0].arn
  prefix_list_alias = "irelandipv4routes"

  depends_on = [module.nvirginia_spoke_vpcs, module.ireland_spoke_vpcs]
}
