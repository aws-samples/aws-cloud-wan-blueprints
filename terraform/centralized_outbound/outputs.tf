/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- centralized_outbound/outputs.tf ---

# output "cloud_wan" {
#   description = "AWS Cloud WAN resources."
#   value = {
#     global_network = aws_networkmanager_global_network.global_network.id
#     core_network   = aws_networkmanager_core_network.core_network.id
#   }
# }

# output "vpcs" {
#   description = "VPCs created."
#   value = {
#     ireland = {
#       spokes     = { for k, v in module.ireland_spoke_vpcs : k => v.vpc_attributes.id }
#       inspection = module.ireland_inspection_vpc.vpc_attributes.id
#     }
#     nvirginia = {
#       spokes     = { for k, v in module.nvirginia_spoke_vpcs : k => v.vpc_attributes.id }
#       inspection = module.nvirginia_inspection_vpc.vpc_attributes.id
#     }
#     sydney = {
#       spokes     = { for k, v in module.sydney_spoke_vpcs : k => v.vpc_attributes.id }
#       inspection = module.sydney_inspection_vpc.vpc_attributes.id
#     }
#   }
# }