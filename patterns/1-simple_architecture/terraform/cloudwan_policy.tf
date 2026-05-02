/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/1-simple_architecture/terraform/cloudwan_policy.tf ---

locals {
  segments = {
    production = {
      require_attachment_acceptance = false
      isolate_attachments           = true
    }
    development = {
      require_attachment_acceptance = false
      isolate_attachments           = false
    }
    shared = {
      require_attachment_acceptance = false
      isolate_attachments           = true
    }
  }
}

data "aws_networkmanager_core_network_policy_document" "policy" {
  version = "2025.11"

  core_network_configuration {
    vpn_ecmp_support = false
    asn_ranges       = ["64520-64525"]

    dynamic "edge_locations" {
      for_each = var.aws_regions
      iterator = region

      content {
        location = region.value
      }
    }
  }

  dynamic "segments" {
    for_each = local.segments
    iterator = segment

    content {
      name                          = segment.key
      require_attachment_acceptance = segment.value.require_attachment_acceptance
      isolate_attachments           = segment.value.isolate_attachments
    }
  }

  segment_actions {
    action     = "share"
    mode       = "attachment-route"
    segment    = "shared"
    share_with = ["production", "development"]
  }

  attachment_policies {
    rule_number     = 100
    condition_logic = "and"

    conditions {
      type = "tag-exists"
      key  = "domain"
    }

    conditions {
      type     = "attachment-type"
      operator = "equals"
      value    = "vpc"
    }

    action {
      association_method = "tag"
      tag_value_of_key   = "domain"
    }
  }

  attachment_policies {
    rule_number     = 200
    condition_logic = "or"

    conditions {
      type     = "tag-value"
      operator = "equals"
      key      = "sharedservice"
      value    = "true"
    }

    action {
      association_method = "constant"
      segment            = "shared"
    }
  }
}
