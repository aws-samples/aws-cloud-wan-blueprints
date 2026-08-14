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
# Neither of these is an edge location - the edge locations come from the policy
# document. These are the two Regions this deployment has to talk to:
#   oregon    - Cloud WAN's home Region, where the global and core network are managed.
#   nvirginia - the only Region AWS RAM can share a global resource from.
variable "aws_regions" {
  type        = map(string)
  description = "Regions this deployment is managed from: oregon is Cloud WAN's home Region, nvirginia is where AWS RAM shares the core network from. Not edge locations."
  default = {
    nvirginia = "us-east-1"
    oregon    = "us-west-2"
  }
}

# Cloud WAN network policy
variable "policy_document" {
  type        = string
  description = "Path to the Cloud WAN network policy JSON document to deploy."
  default     = "../baseline.json"
}

# ---------- AWS RAM SHARE ----------
# Who the core network is shared with. Pick whichever you can test with: a single
# account, an organizational unit, or a whole organization.
#
# `account` takes a 12-digit account ID and works whether or not that account is in your organization.
# `organizational_unit` and `organization` take an Organizations ARN and need RAM sharing with AWS Organizations enabled once, from the management account: aws ram enable-sharing-with-aws-organization`.
variable "share_with" {
  type = object({
    type  = string
    value = string
  })
  description = "Who to share the core network with. Type is `account`, `organizational_unit` or `organization`; value is a 12-digit account ID or an AWS Organizations ARN."

  validation {
    condition     = contains(["account", "organizational_unit", "organization"], var.share_with.type)
    error_message = "share_with.type must be one of: account, organizational_unit, organization."
  }

  validation {
    condition     = var.share_with.type != "account" || can(regex("^[0-9]{12}$", var.share_with.value))
    error_message = "For type \"account\", share_with.value must be a 12-digit AWS account ID, for example \"111122223333\"."
  }

  validation {
    condition     = var.share_with.type != "organizational_unit" || can(regex("^arn:[^:]+:organizations::[0-9]{12}:ou/o-[a-z0-9]+/ou-[0-9a-z]+-[0-9a-z]+$", var.share_with.value))
    error_message = "For type \"organizational_unit\", share_with.value must be an OU ARN, for example \"arn:aws:organizations::111122223333:ou/o-abc123def4/ou-ab12-cdef3456\"."
  }

  validation {
    condition     = var.share_with.type != "organization" || can(regex("^arn:[^:]+:organizations::[0-9]{12}:organization/o-[a-z0-9]+$", var.share_with.value))
    error_message = "For type \"organization\", share_with.value must be an organization ARN, for example \"arn:aws:organizations::111122223333:organization/o-abc123def4\"."
  }
}
