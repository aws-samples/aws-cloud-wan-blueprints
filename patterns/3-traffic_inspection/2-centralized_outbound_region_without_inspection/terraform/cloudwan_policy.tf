/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- centralized_outbound/cloudwan_policys.tf ---

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

  network_function_groups {
    name                          = "inspectionVpcs"
    require_attachment_acceptance = false
  }

  segment_actions {
    action  = "send-to"
    segment = "production"

    via {
      network_function_groups = ["inspectionVpcs"]
      with_edge_override {
        edge_sets = [
          ["eu-west-2"]
        ]
        use_edge_location = "eu-west-1"
      }
    }
  }

  segment_actions {
    action  = "send-to"
    segment = "development"

    via {
      network_function_groups = ["inspectionVpcs"]
      with_edge_override {
        edge_sets = [
          ["eu-west-2"]
        ]
        use_edge_location = "eu-west-1"
      }
    }
  }

  attachment_policies {
    rule_number     = 100
    condition_logic = "or"

    conditions {
      type     = "tag-value"
      operator = "equals"
      key      = "inspection"
      value    = "true"
    }
    action {
      add_to_network_function_group = "inspectionVpcs"
    }
  }

  attachment_policies {
    rule_number     = 200
    condition_logic = "or"

    conditions {
      type = "tag-exists"
      key  = "domain"
    }
    action {
      association_method = "tag"
      tag_value_of_key   = "domain"
    }
  }
}
