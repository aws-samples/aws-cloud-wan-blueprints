/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- infra/tf_modules/compute/outputs.tf ---

output "ec2_instances" {
  description = "List of instances created."
  value       = aws_instance.ec2_instance
}
