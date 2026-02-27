/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/4-advanced_routing/7-summarization/terraform/outputs.tf ---

output "cloud_wan" {
  description = "AWS Cloud WAN resources."
  value = {
    global_network = aws_networkmanager_global_network.global_network.id
    core_network   = aws_networkmanager_core_network.core_network.id
  }
}

output "vpcs" {
  description = "VPCs created."
  value = {
    ireland   = { for k, v in module.ireland_spoke_vpcs : k => v.vpc_attributes.id }
    nvirginia = { for k, v in module.nvirginia_spoke_vpcs : k => v.vpc_attributes.id }
  }
}
