/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/4-hybrid/terraform/providers.tf ---

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

# The AWSCC provider manages the global network and core network.
provider "awscc" {
  region = var.aws_regions.nvirginia
  alias  = "awsccnvirginia"
}

# Provider definitions for Ireland Region
provider "aws" {
  region = var.aws_regions.ireland
  alias  = "awsireland"
}

# Provider for Cloud WAN's HOME Region (us-west-2).
#
# Managed prefix lists associated with a core network MUST be created in the home
# Region, regardless of where the edge locations are. This alias exists only for the
# prefix lists that route summarization matches on.
provider "aws" {
  region = var.aws_regions.home
  alias  = "awshome"
}
