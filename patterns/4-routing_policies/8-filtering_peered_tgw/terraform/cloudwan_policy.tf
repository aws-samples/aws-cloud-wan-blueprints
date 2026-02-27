/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/4-advanced_routing/8-filtering_peered_tgw/terraform/cloudwan_policy.tf ---

locals {
  asn_ranges = ["65000-65003"]
  asn_per_region = {
    nvirginia = 65000
    ireland   = 65001
  }
  segments = {
    legacy = {
      require_attachment_acceptance = false
    }
  }
}

data "aws_networkmanager_core_network_policy_document" "policy_document" {
  version = "2025.11"

  core_network_configuration {
    vpn_ecmp_support                   = true
    dns_support                        = true
    security_group_referencing_support = true
    asn_ranges                         = local.asn_ranges

    dynamic "edge_locations" {
      for_each = var.aws_regions
      iterator = region

      content {
        location = region.value
        asn      = local.asn_per_region[region.key]
      }
    }
  }

  dynamic "segments" {
    for_each = local.segments
    iterator = segment

    content {
      name                          = segment.key
      require_attachment_acceptance = segment.value.require_attachment_acceptance
    }
  }

  attachment_policies {
    rule_number     = 100
    condition_logic = "and"

    conditions {
      type     = "attachment-type"
      operator = "equals"
      value    = "transit-gateway-route-table"
    }

    action {
      association_method = "constant"
      segment            = "legacy"
    }
  }

  attachment_routing_policy_rules {
    rule_number = 100

    conditions {
      type  = "routing-policy-label"
      value = "tgwAttachment"
    }

    action {
      associate_routing_policies = ["filterIPv4"]
    }
  }

  routing_policies {
    routing_policy_name      = "filterIPv4"
    routing_policy_direction = "inbound"
    routing_policy_number    = 100

    routing_policy_rules {
      rule_number = 100

      rule_definition {
        condition_logic = "or"

        match_conditions {
          type  = "prefix-in-cidr"
          value = "0.0.0.0/0"
        }

        match_conditions {
          type  = "prefix-equals"
          value = "0.0.0.0/0"
        }

        action {
          type = "drop"
        }
      }
    }
  }
}