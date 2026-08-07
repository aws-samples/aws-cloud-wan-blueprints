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

# This pattern runs entirely in the NETWORKING account. It creates no workloads, so it
# needs only one Region's providers - the API endpoint used to manage the core network
# and to create the AWS RAM share. Edge locations come from the policy document.
provider "aws" {
  region = var.aws_regions.nvirginia
  alias  = "awsnvirginia"
}

provider "awscc" {
  region = var.aws_regions.nvirginia
  alias  = "awsccnvirginia"
}
