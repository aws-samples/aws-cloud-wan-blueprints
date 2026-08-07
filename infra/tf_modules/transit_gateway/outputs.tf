/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/tf_modules/transit_gateway/outputs.tf ---

output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = aws_ec2_transit_gateway.transit_gateway.id
}

output "transit_gateway_arn" {
  description = "Transit Gateway ARN."
  value       = aws_ec2_transit_gateway.transit_gateway.arn
}

output "route_table_ids" {
  description = "Transit Gateway route table IDs, keyed by route table name."
  value       = { for k, v in aws_ec2_transit_gateway_route_table.tgw_route_table : k => v.id }
}

output "cloud_wan_peering_id" {
  description = "Cloud WAN Transit Gateway peering ID."
  value       = aws_networkmanager_transit_gateway_peering.tgw_cwan_peering.id
}

output "cloud_wan_route_table_attachment_ids" {
  description = "Cloud WAN transit-gateway-route-table attachment IDs, keyed by route table name."
  value       = { for k, v in aws_networkmanager_transit_gateway_route_table_attachment.rt_attachment : k => v.id }
}
