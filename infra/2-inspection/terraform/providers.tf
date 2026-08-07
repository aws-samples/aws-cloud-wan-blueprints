/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/2-inspection/terraform/providers.tf ---

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.34.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.67.0"
    }
  }
}

# Provider definitions for N. Virginia Region
provider "aws" {
  region = var.aws_regions.nvirginia
  alias  = "awsnvirginia"
}

# The AWSCC provider manages the global network and core network. Cloud WAN is a
# global service, so this alias is only the API endpoint used to manage it - it is
# not a constraint on where Core Network Edges are created. Edge locations come
# from the policy document.
provider "awscc" {
  region = var.aws_regions.nvirginia
  alias  = "awsccnvirginia"
}

# Provider definitions for Ireland Region
provider "aws" {
  region = var.aws_regions.ireland
  alias  = "awsireland"
}
