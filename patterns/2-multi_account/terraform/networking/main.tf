/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/2-multi_account/terraform/networking/main.tf ---

# ---------- AWS CLOUD WAN RESOURCES ----------
# Global Network
resource "aws_networkmanager_global_network" "global_network" {
  description = "Global Network - ${var.identifier}"

  tags = {
    Name = "Global Network - ${var.identifier}"
  }
}

# Core Network
resource "aws_networkmanager_core_network" "core_network" {
  global_network_id = aws_networkmanager_global_network.global_network.id
  description       = "Core Network - ${var.identifier}"

  tags = {
    Name = "Core Network - ${var.identifier}"
  }
}

resource "aws_networkmanager_core_network_policy_attachment" "core_network_policy" {
  core_network_id = aws_networkmanager_core_network.core_network.id
  policy_document = data.aws_networkmanager_core_network_policy_document.policy.json
}

# ---------- RAM SHARE ----------
resource "aws_ram_resource_share" "resource_share" {
  name                      = "resource-share-${var.identifier}"
  allow_external_principals = true
}

resource "aws_ram_resource_association" "core_network_resource_association" {
  resource_arn       = aws_networkmanager_core_network.core_network.arn
  resource_share_arn = aws_ram_resource_share.resource_share.arn
}

resource "aws_ram_principal_association" "spoke_account_association" {
  principal          = var.spoke_account
  resource_share_arn = aws_ram_resource_share.resource_share.arn
}
