/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/6-prefix_list_association/terraform/outputs.tf ---

output "cloud_wan" {
  description = "AWS Cloud WAN resources."
  value = {
    global_network_id = aws_networkmanager_global_network.global_network.id
    core_network_id   = aws_networkmanager_core_network.core_network.id
  }
}

output "prefix_list" {
  description = "The managed prefix list."
  value       = aws_ec2_managed_prefix_list.prefix_list.id
}
