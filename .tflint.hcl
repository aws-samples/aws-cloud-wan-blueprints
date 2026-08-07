# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Repository TFLint configuration for AWS Cloud WAN Blueprints.
#
# Used by the static-only CI (.github/workflows/ci.yml) and by local pre-commit.
# The AWS ruleset is enabled so `tflint` checks for invalid AWS resource
# arguments, deprecated syntax, and naming issues across every pattern's
# Terraform. `tflint --init` installs the plugin declared below; CI passes this
# file via `--config` so every pattern directory is linted with the same ruleset.
#
# NOTE: this file must stay committed. An earlier revision of .gitignore ignored
# it, which left the tflint hook running without a ruleset.

config {
  # Lint only the module in the working directory. The shared child modules in
  # infra/tf_modules/* declare no provider configuration of their own; they are
  # linted transitively from the pattern roots under infra/*/terraform that call
  # them.
  call_module_type = "local"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.42.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
