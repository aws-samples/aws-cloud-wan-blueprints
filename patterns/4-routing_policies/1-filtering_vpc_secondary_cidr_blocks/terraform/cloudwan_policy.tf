/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- patterns/4-advanced_routing/1-filtering_vpc_secondary_cidr_blocks/terraform/cloudwan_policy.tf ---

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

  attachment_routing_policy_rules {
    rule_number = 100

    conditions {
      type  = "routing-policy-label"
      value = "vpcAttachments"
    }

    action {
      associate_routing_policies = ["secondaryCidrFiltering"]
    }
  }

  routing_policies {
    routing_policy_name        = "secondaryCidrFiltering"
    routing_policy_description = "Attachment IPv4 secondary CIDR block filtering"
    routing_policy_direction   = "inbound"
    routing_policy_number      = 100

    routing_policy_rules {
      rule_number = 100

      rule_definition {
        condition_logic = "or"

        match_conditions {
          type  = "prefix-equals"
          value = "10.100.0.0/16"
        }

        action {
          type = "drop"
        }
      }
    }
  }
}