/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- east_west/modules/inspection/main.tf ---

# AWS Network Firewall resource
module "networkfirewall" {
  source  = "aws-ia/networkfirewall/aws"
  version = "0.0.2"

  network_firewall_name   = "anfw-${var.identifier}"
  network_firewall_policy = aws_networkfirewall_firewall_policy.anfw_policy.arn
  vpc_id                  = var.vpc.vpc_attributes.id
  number_azs              = var.number_azs
  vpc_subnets             = { for k, v in var.vpc.private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "inspection" }

  routing_configuration = {
    centralized_inspection_without_egress = {
      tgw_subnet_route_tables = { for k, v in var.vpc.rt_attributes_by_type_by_az.core_network : k => v.id }
    }
  }
}