/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/5-multi_account/terraform/main.tf ---

# ---------- AWS CLOUD WAN ----------
# Global Network
resource "awscc_networkmanager_global_network" "global_network" {
  provider = awscc.awsccnvirginia

  description = "Global Network - ${var.identifier}"

  tags = [{
    key   = "Name"
    value = "global-network-${var.identifier}"
  }]
}

# Core Network
#
# The policy document is read from a file so that the SAME document is consumed by both
# this Terraform and the CloudFormation implementation. See V2.md section 6.
resource "awscc_networkmanager_core_network" "core_network" {
  provider = awscc.awsccnvirginia

  global_network_id = awscc_networkmanager_global_network.global_network.id
  description       = "Core Network - ${var.identifier}"
  policy_document   = file(var.policy_document)

  tags = [{
    key   = "Name"
    value = "core-network-${var.identifier}"
  }]
}

# ---------- AWS RAM SHARE ----------
# Shares the CORE NETWORK with other accounts, so they can create attachments into its
# segments from their own VPCs.
#
# This is the whole pattern. Deliberately no workloads: the other patterns answer "which
# attachment types exist", this one answers "who owns them". Pair it with any other
# pattern's workload code deployed in the spoke account.
resource "aws_ram_resource_share" "core_network_share" {
  provider = aws.awsnvirginia

  name                      = "core-network-share-${var.identifier}"
  allow_external_principals = var.allow_external_principals

  tags = {
    Name = "core-network-share-${var.identifier}"
  }
}

resource "aws_ram_resource_association" "core_network" {
  provider = aws.awsnvirginia

  resource_arn       = awscc_networkmanager_core_network.core_network.core_network_arn
  resource_share_arn = aws_ram_resource_share.core_network_share.arn
}

# One association per principal. Prefer specific account IDs or organizational unit ARNs
# over an entire organization ARN: a principal that can see the core network can create
# attachments into it, and the segment those land in is decided by a tag THEY set.
resource "aws_ram_principal_association" "principals" {
  for_each = toset(var.share_with_principals)
  provider = aws.awsnvirginia

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.core_network_share.arn
}
