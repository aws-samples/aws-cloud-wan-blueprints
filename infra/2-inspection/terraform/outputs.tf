/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/2-inspection/terraform/outputs.tf ---

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

output "inspection_vpcs" {
  description = "Inspection VPCs created, by Region."
  value = {
    (var.aws_regions.nvirginia) = module.nvirginia_inspection_vpc.central_vpcs.inspection.vpc_attributes.id
    (var.aws_regions.ireland)   = module.ireland_inspection_vpc.central_vpcs.inspection.vpc_attributes.id
  }
}

output "policy_document" {
  description = "Path to the Cloud WAN network policy document deployed."
  value       = var.policy_document
}
