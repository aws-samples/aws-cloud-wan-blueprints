/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/tf_modules/transit_gateway/main.tf ---

data "aws_region" "current" {}

# ---------- TRANSIT GATEWAY ----------
# Default association and propagation are DISABLED so every association is explicit.
# Implicit default-route-table behaviour is the usual source of "why can these two VPCs
# reach each other" surprises in a segmented Transit Gateway design.
resource "aws_ec2_transit_gateway" "transit_gateway" {
  amazon_side_asn                 = var.tgw_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  description                     = "Transit Gateway - ${data.aws_region.current.region}"

  tags = {
    Name = "tgw-${data.aws_region.current.region}-${var.identifier}"
  }
}

# ---------- TRANSIT GATEWAY ROUTE TABLES ----------
# One route table per entry in var.route_tables. Each becomes a Cloud WAN
# transit-gateway-route-table attachment below.
resource "aws_ec2_transit_gateway_route_table" "tgw_route_table" {
  for_each = var.route_tables

  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id

  tags = {
    Name = "tgw-rt-${each.key}-${data.aws_region.current.region}-${var.identifier}"
  }
}

# Associate each spoke VPC attachment with the route table it belongs to. The
# association decides which route table the VPC's traffic is looked up in.
resource "aws_ec2_transit_gateway_route_table_association" "tgw_association" {
  for_each = var.vpc_information

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table[each.value.route_table].id
}

# Propagate each spoke VPC's routes into the same route table, so VPCs sharing a route
# table can reach each other and their prefixes reach Cloud WAN.
resource "aws_ec2_transit_gateway_route_table_propagation" "tgw_propagation" {
  for_each = var.vpc_information

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table[each.value.route_table].id
}

# ---------- CLOUD WAN PEERING ----------
# Peers the Transit Gateway with the Cloud WAN core network. The peering itself carries
# no routes; the route-table attachments below do.
resource "aws_networkmanager_transit_gateway_peering" "tgw_cwan_peering" {
  core_network_id     = var.core_network_id
  transit_gateway_arn = aws_ec2_transit_gateway.transit_gateway.arn

  tags = {
    Name = "tgw-cwan-peering-${data.aws_region.current.region}-${var.identifier}"
  }
}

# A Transit Gateway policy table is required for the Cloud WAN peering attachment.
resource "aws_ec2_transit_gateway_policy_table" "tgw_policy_table" {
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id

  tags = {
    Name = "tgw-policy-table-${data.aws_region.current.region}-${var.identifier}"
  }
}

resource "aws_ec2_transit_gateway_policy_table_association" "tgw_policy_table_assoc" {
  transit_gateway_attachment_id   = aws_networkmanager_transit_gateway_peering.tgw_cwan_peering.transit_gateway_peering_attachment_id
  transit_gateway_policy_table_id = aws_ec2_transit_gateway_policy_table.tgw_policy_table.id
}

# ---------- CLOUD WAN ROUTE TABLE ATTACHMENTS ----------
# Each Transit Gateway route table is attached to Cloud WAN as a
# `transit-gateway-route-table` attachment, tagged with `domain` so the attachment
# policy associates it to the matching segment. This is where the Transit Gateway's
# routing domains join the Cloud WAN segments.
#
# NOTE: route-table attachments that share a peering AND land in the same segment share
# their outbound routing policies. Keep one route table per segment to avoid surprises.
resource "aws_networkmanager_transit_gateway_route_table_attachment" "rt_attachment" {
  for_each = var.route_tables

  peering_id                      = aws_networkmanager_transit_gateway_peering.tgw_cwan_peering.id
  transit_gateway_route_table_arn = aws_ec2_transit_gateway_route_table.tgw_route_table[each.key].arn

  tags = {
    Name = "tgw-rt-attachment-${each.key}-${data.aws_region.current.region}-${var.identifier}"

    # Attachment tagging contract (infra/README.md): `domain` names the segment.
    domain = each.value
  }
}
