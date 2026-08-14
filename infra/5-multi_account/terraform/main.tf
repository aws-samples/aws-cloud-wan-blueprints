/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/5-multi_account/terraform/main.tf ---

# ---------- AWS CLOUD WAN ----------
# Global Network
resource "awscc_networkmanager_global_network" "global_network" {
  provider = awscc.awsccoregon

  description = "Global Network - ${var.identifier}"

  tags = [{
    key   = "Name"
    value = "global-network-${var.identifier}"
  }]
}

# Core Network
resource "awscc_networkmanager_core_network" "core_network" {
  provider = awscc.awsccoregon

  global_network_id = awscc_networkmanager_global_network.global_network.id
  description       = "Core Network - ${var.identifier}"
  policy_document   = file(var.policy_document)

  tags = [{
    key   = "Name"
    value = "core-network-${var.identifier}"
  }]
}

# ---------- AWS RAM SHARE ----------
# Shares the CORE NETWORK with a spoke account, organizational unit, or organization
locals {
  # Sharing with an account ID needs external principals allowed, which also covers an account that is in your organization.
  allow_external_principals = var.share_with.type == "account"
}

resource "aws_ram_resource_share" "core_network_share" {
  provider = aws.awsnvirginia

  name                      = "core-network-share-${var.identifier}"
  allow_external_principals = local.allow_external_principals

  tags = {
    Name = "core-network-share-${var.identifier}"
  }
}

# Resource association: Cloud WAN's core network
resource "aws_ram_resource_association" "core_network" {
  provider = aws.awsnvirginia

  resource_arn       = awscc_networkmanager_core_network.core_network.core_network_arn
  resource_share_arn = aws_ram_resource_share.core_network_share.arn
}

# Principal association: account, organizational unit, or organization
resource "aws_ram_principal_association" "principal" {
  provider = aws.awsnvirginia

  principal          = var.share_with.value
  resource_share_arn = aws_ram_resource_share.core_network_share.arn
}
