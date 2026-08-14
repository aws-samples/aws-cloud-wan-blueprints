/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/6-prefix_list_association/terraform/providers.tf ---

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.34.0"
    }
  }
}

# Oregon provider (aws)
provider "aws" {
  region = var.aws_regions.oregon
  alias  = "awsoregon"
}
