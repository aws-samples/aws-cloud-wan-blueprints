/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- east_west_dualhop/providers.tf ---

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.67.0"
    }
  }
}

# Provider definition for Ireland Region
provider "aws" {
  region = var.aws_regions.ireland
  alias  = "awsireland"
}

# Provider definition for N. Virginia Region
provider "aws" {
  region = var.aws_regions.nvirginia
  alias  = "awsnvirginia"
}

# Provider definition for Sydney Region
provider "aws" {
  region = var.aws_regions.sydney
  alias  = "awssydney"
}

# Provider definitios for London Region
provider "aws" {
  region = var.aws_regions.london
  alias  = "awslondon"
}
