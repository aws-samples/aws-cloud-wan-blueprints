/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/7-attachment_nat/terraform/outputs.tf ---

output "cloud_wan" {
  description = "AWS Cloud WAN resources."
  value = {
    global_network = awscc_networkmanager_global_network.global_network.global_network_id
    core_network   = awscc_networkmanager_core_network.core_network.core_network_id
  }
}

output "vpcs" {
  description = "VPCs created, by Region: the VPC ID, its real CIDR, the NAT CIDR other networks reach it at (null without NAT), and its VPC attachment ID."
  value = {
    (var.aws_regions.nvirginia) = { for k, v in module.nvirginia_vpcs : k => {
      vpc_id        = v.vpc_attributes.id
      cidr_block    = var.nvirginia_vpcs[k].cidr_block
      nat_cidr      = var.nvirginia_vpcs[k].nat_cidr
      attachment_id = try(awscc_networkmanager_vpc_attachment.nvirginia[k].attachment_id, awscc_networkmanager_vpc_attachment.nvirginia_nat[k].attachment_id)
    } }
    (var.aws_regions.ireland) = { for k, v in module.ireland_vpcs : k => {
      vpc_id        = v.vpc_attributes.id
      cidr_block    = var.ireland_vpcs[k].cidr_block
      nat_cidr      = var.ireland_vpcs[k].nat_cidr
      attachment_id = awscc_networkmanager_vpc_attachment.ireland_nat[k].attachment_id
    } }
  }
}

output "site_to_site_vpn_attachment" {
  description = "Site-to-Site VPN attachment ID. null when the VPN is not enabled."
  value       = try(awscc_networkmanager_site_to_site_vpn_attachment.vpn_attachment[0].attachment_id, null)
}
