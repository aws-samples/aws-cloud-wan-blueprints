/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/4-routing_policies/9-inbound_route_filtering/terraform/outputs.tf ---

output "cloud_wan" {
  description = "AWS Cloud WAN resources."
  value = {
    global_network = awscc_networkmanager_global_network.global_network.global_network_id
    core_network   = awscc_networkmanager_core_network.core_network.core_network_id
  }
}

output "dx_gateway" {
  description = "Direct Connect Gateway."
  value = {
    id  = aws_dx_gateway.dxgw.id
    asn = aws_dx_gateway.dxgw.amazon_side_asn
  }
}

output "prefix_list" {
  description = "Managed prefix list for dangerous routes."
  value = {
    id  = aws_ec2_managed_prefix_list.dangerous_prefixes.id
    arn = aws_ec2_managed_prefix_list.dangerous_prefixes.arn
  }
}
