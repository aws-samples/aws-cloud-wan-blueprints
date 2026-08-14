/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/3-transit_gateway/terraform/outputs.tf ---

output "cloud_wan" {
  description = "AWS Cloud WAN resources."
  value = {
    global_network = awscc_networkmanager_global_network.global_network.global_network_id
    core_network   = awscc_networkmanager_core_network.core_network.core_network_id
  }
}

output "spoke_vpcs" {
  description = "Spoke VPCs created, by Region."
  value = {
    (var.aws_regions.nvirginia) = { for k, v in module.nvirginia_spoke_vpcs : k => v.vpc_attributes.id }
    (var.aws_regions.ireland)   = { for k, v in module.ireland_spoke_vpcs : k => v.vpc_attributes.id }
  }
}

output "transit_gateways" {
  description = "Transit Gateways created, by Region."
  value = {
    (var.aws_regions.nvirginia) = aws_ec2_transit_gateway.nvirginia_transit_gateway.id
    (var.aws_regions.ireland)   = aws_ec2_transit_gateway.ireland_transit_gateway.id
  }
}

output "transit_gateway_route_tables" {
  description = "Transit Gateway route tables created, by Region and segment."
  value = {
    (var.aws_regions.nvirginia) = {
      production  = aws_ec2_transit_gateway_route_table.nvirginia_tgw_production_rt.id
      development = aws_ec2_transit_gateway_route_table.nvirginia_tgw_development_rt.id
    }
    (var.aws_regions.ireland) = {
      production  = aws_ec2_transit_gateway_route_table.ireland_tgw_production_rt.id
      development = aws_ec2_transit_gateway_route_table.ireland_tgw_development_rt.id
    }
  }
}

output "cloud_wan_peerings" {
  description = "Transit Gateway peerings with the core network, by Region."
  value = {
    (var.aws_regions.nvirginia) = aws_networkmanager_transit_gateway_peering.nvirginia_tgw_cwan_peering.id
    (var.aws_regions.ireland)   = aws_networkmanager_transit_gateway_peering.ireland_tgw_cwan_peering.id
  }
}

output "cloud_wan_route_table_attachments" {
  description = "Cloud WAN transit-gateway-route-table attachments, by Region and segment."
  value = {
    (var.aws_regions.nvirginia) = {
      production  = aws_networkmanager_transit_gateway_route_table_attachment.nvirginia_production_rt_attachment.id
      development = aws_networkmanager_transit_gateway_route_table_attachment.nvirginia_development_rt_attachment.id
    }
    (var.aws_regions.ireland) = {
      production  = aws_networkmanager_transit_gateway_route_table_attachment.ireland_production_rt_attachment.id
      development = aws_networkmanager_transit_gateway_route_table_attachment.ireland_development_rt_attachment.id
    }
  }
}
