/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/1-basic/terraform/providers.tf ---

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

# AWSCC provider definition
provider "awscc" {
  region = var.aws_regions.nvirginia
  alias  = "awsccnvirginia"
}

# Provider definitions for Ireland Region
provider "aws" {
  region = var.aws_regions.ireland
  alias  = "awsireland"
}
