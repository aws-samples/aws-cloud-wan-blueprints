/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/5-multi_account/terraform/variables.tf ---

# Project Identifier
variable "identifier" {
  type        = string
  description = "Project identifier, used as a suffix when naming resources."
  default     = "multi-account"
}

# AWS Regions
#
# These are the Region set the core network's edge locations cover. This pattern creates
# no workloads, so no per-Region resources are built here - the Regions must still match
# the policy's edge-locations.
variable "aws_regions" {
  type        = map(string)
  description = "AWS Regions the core network spans. Must match the edge-locations in the policy document."
  default = {
    nvirginia = "us-east-1"
    ireland   = "eu-west-1"
  }
}

# Cloud WAN network policy
variable "policy_document" {
  type        = string
  description = "Path to the Cloud WAN network policy JSON document to deploy."
  default     = "../baseline.json"
}

# AWS RAM share principals.
#
# Accept an AWS account ID (e.g. "111122223333"), an organization ARN, or an
# organizational unit ARN. Prefer specific accounts or OUs over a whole organization:
# sharing a core network grants the ability to create attachments into your segments.
variable "share_with_principals" {
  type        = list(string)
  description = "Principals to share the core network with: account IDs, or Organization / OU ARNs."
  default     = []
}

# Whether the share requires the receiving account to accept the invitation.
#
# false when both accounts are in the same AWS Organization with RAM sharing enabled -
# the share is then auto-accepted.
variable "allow_external_principals" {
  type        = bool
  description = "Allow sharing with principals outside your AWS Organization."
  default     = false
}
