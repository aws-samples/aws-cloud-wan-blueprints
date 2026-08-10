/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/6-prefix_list_association/terraform/main.tf ---

# ---------- AWS CLOUD WAN ----------
# Global Network
resource "aws_networkmanager_global_network" "global_network" {
  provider = aws.awsoregon

  description = "Global Network - ${var.identifier}"

  tags = {
    Name = "global-network-${var.identifier}"
  }
}

# Core Network (with base policy)
resource "aws_networkmanager_core_network" "core_network" {
  provider = aws.awsoregon

  global_network_id    = aws_networkmanager_global_network.global_network.id
  description          = "Core Network - ${var.identifier}"
  base_policy_document = file(var.policy_document)
  create_base_policy   = true

  tags = {
    Name = "core-network-${var.identifier}"
  }
}

# Core Network policy attachment (post prefix list association)
resource "aws_networkmanager_core_network_policy_attachment" "prefix_list_policy" {
  provider = aws.awsoregon

  core_network_id = aws_networkmanager_core_network.core_network.id
  policy_document = file(var.prefix_list_policy_document)

  depends_on = [aws_networkmanager_prefix_list_association.prefix_list_association]
}

# ---------- PREFIX LIST ----------
# Managed prefix list
resource "aws_ec2_managed_prefix_list" "prefix_list" {
  provider = aws.awsoregon

  name           = "prefixlist-${var.identifier}"
  address_family = "IPv4"
  max_entries    = length(var.prefix_list_cidrs)
}

resource "aws_ec2_managed_prefix_list_entry" "prefix_list_entry" {
  for_each = toset(var.prefix_list_cidrs)
  provider = aws.awsoregon

  cidr           = each.value
  prefix_list_id = aws_ec2_managed_prefix_list.prefix_list.id
}

# ---------- CLOUD WAN PREFIX LIST ASSOCIATION ----------
resource "aws_networkmanager_prefix_list_association" "prefix_list_association" {
  provider = aws.awsoregon

  core_network_id   = aws_networkmanager_core_network.core_network.id
  prefix_list_arn   = aws_ec2_managed_prefix_list.prefix_list.arn
  prefix_list_alias = var.prefix_list_alias
}
