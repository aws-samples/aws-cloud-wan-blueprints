/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/4-advanced_routing/7-summarization/terraform/cloudwan_policy.tf ---

locals {
  asn_ranges = ["65000-65003"]
  asn_per_region = {
    nvirginia = 65000
    ireland   = 65001
  }
  segments = {
    production = {
      require_attachment_acceptance = false
    }
    development = {
      require_attachment_acceptance = false
    }
    hybrid = {
      require_attachment_acceptance = false
    }
  }
}

data "aws_networkmanager_core_network_policy_document" "base_policy_document" {
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

  segment_actions {
    action     = "share"
    mode       = "attachment-route"
    segment    = "hybrid"
    share_with = ["production", "development"]
  }

  attachment_policies {
    rule_number     = 100
    condition_logic = "and"

    conditions {
      type     = "attachment-type"
      operator = "equals"
      value    = "vpc"
    }

    conditions {
      type = "tag-exists"
      key  = "domain"
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
      type     = "attachment-type"
      operator = "equals"
      value    = "site-to-site-vpn"
    }

    conditions {
      type     = "attachment-type"
      operator = "equals"
      value    = "connect"
    }

    conditions {
      type     = "attachment-type"
      operator = "equals"
      value    = "direct-connect-gateway"
    }

    action {
      association_method = "constant"
      segment            = "hybrid"
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

  segment_actions {
    action     = "share"
    mode       = "attachment-route"
    segment    = "hybrid"
    share_with = ["production", "development"]
  }

  attachment_policies {
    rule_number     = 100
    condition_logic = "and"

    conditions {
      type     = "attachment-type"
      operator = "equals"
      value    = "vpc"
    }

    conditions {
      type = "tag-exists"
      key  = "domain"
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
      type     = "attachment-type"
      operator = "equals"
      value    = "site-to-site-vpn"
    }

    conditions {
      type     = "attachment-type"
      operator = "equals"
      value    = "connect"
    }

    conditions {
      type     = "attachment-type"
      operator = "equals"
      value    = "direct-connect-gateway"
    }

    action {
      association_method = "constant"
      segment            = "hybrid"
    }
  }

  attachment_routing_policy_rules {
    rule_number = 100

    conditions {
      type  = "routing-policy-label"
      value = "vpnAttachment"
    }

    action {
      associate_routing_policies = ["summarizeIpv4Routes"]
    }
  }

  attachment_routing_policy_rules {
    rule_number = 200

    conditions {
      type  = "routing-policy-label"
      value = "connectAttachment"
    }

    action {
      associate_routing_policies = ["summarizeIpv4Routes"]
    }
  }

  attachment_routing_policy_rules {
    rule_number = 300

    conditions {
      type  = "routing-policy-label"
      value = "dxAttachment"
    }

    action {
      associate_routing_policies = ["summarizeNVirginiaIpv4Routes", "summarizeIrelandIpv4Routes"]
    }
  }

  routing_policies {
    routing_policy_name      = "summarizeIpv4Routes"
    routing_policy_direction = "outbound"
    routing_policy_number    = 100

    routing_policy_rules {
      rule_number = 100

      rule_definition {
        condition_logic = "or"

        match_conditions {
          type  = "prefix-in-prefix-list"
          value = "nvirginiaipv4routes"
        }

        match_conditions {
          type  = "prefix-in-prefix-list"
          value = "irelandipv4routes"
        }

        action {
          type  = "summarize"
          value = "10.0.0.0/8"
        }
      }
    }
  }

  routing_policies {
    routing_policy_name      = "summarizeNVirginiaIpv4Routes"
    routing_policy_direction = "outbound"
    routing_policy_number    = 200

    routing_policy_rules {
      rule_number = 100

      rule_definition {
        condition_logic = "or"

        match_conditions {
          type  = "prefix-in-prefix-list"
          value = "nvirginiaipv4routes"
        }

        action {
          type  = "summarize"
          value = "10.10.0.0/16"
        }
      }
    }
  }

  routing_policies {
    routing_policy_name      = "summarizeIrelandIpv4Routes"
    routing_policy_direction = "outbound"
    routing_policy_number    = 300

    routing_policy_rules {
      rule_number = 100

      rule_definition {
        condition_logic = "or"

        match_conditions {
          type  = "prefix-in-prefix-list"
          value = "irelandipv4routes"
        }

        action {
          type  = "summarize"
          value = "10.0.0.0/16"
        }
      }
    }
  }
}