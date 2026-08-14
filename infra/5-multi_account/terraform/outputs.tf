/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/5-multi_account/terraform/outputs.tf ---

output "cloud_wan" {
  description = "AWS Cloud WAN resources. Pass these to the spoke accounts so they can create attachments."
  value = {
    global_network   = awscc_networkmanager_global_network.global_network.global_network_id
    core_network_id  = awscc_networkmanager_core_network.core_network.core_network_id
    core_network_arn = awscc_networkmanager_core_network.core_network.core_network_arn
  }
}

output "resource_share_arn" {
  description = "AWS RAM resource share ARN. A spoke account outside your Organization needs this to accept the invitation."
  value       = aws_ram_resource_share.core_network_share.arn
}
