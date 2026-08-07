/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/tf_modules/transit_gateway/variables.tf ---

variable "identifier" {
  type        = string
  description = "Project identifier, used as a suffix when naming resources."
}

variable "tgw_asn" {
  type        = number
  description = "Amazon-side ASN for the Transit Gateway. Must not overlap the Cloud WAN core network asn-ranges."
}

variable "core_network_id" {
  type        = string
  description = "Cloud WAN core network ID to peer the Transit Gateway with."
}

# One Transit Gateway route table is created per entry. The KEY is the route table
# name; the VALUE is the segment its Cloud WAN route-table attachment is tagged for
# (the `domain` tag in the attachment tagging contract).
#
# This is how a Transit Gateway route table maps onto a Cloud WAN segment: each route
# table becomes one `transit-gateway-route-table` attachment, and its `domain` tag puts
# it in the matching segment.
variable "route_tables" {
  type        = map(string)
  description = "Transit Gateway route tables to create: route table name => Cloud WAN segment."
  default = {
    production  = "production"
    development = "development"
  }
}

# Spoke VPCs attached to this Transit Gateway. Each entry needs the VPC's TGW
# attachment ID and the route table it belongs to (a key of var.route_tables).
variable "vpc_information" {
  type = map(object({
    transit_gateway_attachment_id = string
    route_table                   = string
  }))
  description = "Spoke VPCs attached to the Transit Gateway, and which route table each belongs to."
}
