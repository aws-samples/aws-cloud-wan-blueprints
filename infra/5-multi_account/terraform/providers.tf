/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/5-multi_account/terraform/providers.tf ---

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

# N. Virginia provider (aws)
provider "aws" {
  region = var.aws_regions.nvirginia
  alias  = "awsnvirginia"
}

# Oregon provider (awscc)
provider "awscc" {
  region = var.aws_regions.oregon
  alias  = "awsccoregon"
}
