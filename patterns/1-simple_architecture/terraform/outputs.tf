/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/1-simple_architecture/terraform/outputs.tf ---

output "cloud_wan" {
  description = "AWS Cloud WAN resources."
  value = {
    global_network = awscc_networkmanager_global_network.global_network.global_network_id
    core_network   = awscc_networkmanager_core_network.core_network.core_network_id
  }
}

output "vpcs" {
  description = "VPCs created."
  value = {
    ireland   = { for k, v in module.ireland_spoke_vpcs : k => v.vpc_attributes.id }
    nvirginia = { for k, v in module.nvirginia_spoke_vpcs : k => v.vpc_attributes.id }
  }
}
