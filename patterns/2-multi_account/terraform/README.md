# AWS Cloud WAN Multi-Account architecture (Terraform)

![Multi-Account Architecture](../../../images/patterns_multi_account.png)

## Prerequisites

- **Two AWS Accounts**: Networking Account and Spoke Account
- **Terraform**: >= 1.3.0 installed
- **AWS CLI**: Configured with credentials for both accounts
- **Permissions required**:
  - **Networking Account**: Network Manager, RAM
  - **Spoke Account**: EC2 (VPC, subnets, instances, endpoints), IAM, RAM

## Deployment

### Step 1: Deploy Core Network (Networking Account)

```bash
# Clone the repository
git clone https://github.com/aws-samples/aws-cloud-wan-blueprints.git
cd patterns/2-multi_account/terraform/networking

# Assume credentials for Networking Account

# Initialize Terraform
terraform init

# Configure the spoke account ID
# Option 1: Create a terraform.tfvars file
echo 'spoke_account = "<your-spoke-account-id>"' > terraform.tfvars

# Option 2: Use -var flag
# terraform apply -var="spoke_account=<your-spoke-account-id>"

# Deploy the Core Network
terraform apply

# Take note of the resource_share_arn output
```

### Step 2: Deploy workloads (Spoke Account)

> **Note**: RAM share acceptance is handled automatically by Terraform. If accounts are in the same AWS Organization with RAM sharing enabled, the share is auto-accepted. If not, Terraform will accept the invitation during deployment.

```bash
# Navigate to spoke folder
cd ../spoke

# Assume credentials for Spoke Account

# Initialize Terraform
terraform init

# Configure the resource share ARN
# Option 1: Create a terraform.tfvars file
echo 'resource_share_arn = "<resource-share-arn-from-step-1>"' > terraform.tfvars

# Option 2: Use -var flag
# terraform apply -var="resource_share_arn=<resource-share-arn>"

# (Optional) Edit variables.tf to customize VPC CIDRs, regions, etc.

# Deploy the workloads
terraform apply
```

> **Note**: EC2 instances will be deployed in all the Availability Zones configured for each VPC. Keep this in mind when testing this environment from a cost perspective - for production environments, we recommend the use of at least 2 AZs for high-availability.

## Cleanup

### Step 1: Destroy workloads (Spoke Account)

```bash
# Assume credentials for Spoke Account
cd spoke/

# Destroy workload resources
terraform destroy
```

### Step 2: Destroy Core Network (Networking Account)

```bash
# Assume credentials for Networking Account
cd ../networking/

# Destroy Core Network resources
terraform destroy
```

## Next Steps

After successfully deploying this pattern:

1. **Explore the architecture**: Review segment associations and routing in Network Manager console
2. **Test connectivity**: Verify traffic flows match expected behavior
3. **Try modifications**: Add VPCs, change segments, update policies
4. **Advanced patterns**: Move to [Traffic inspection](../../3-traffic_inspection/) or [Routing policies](../../4-routing_policies/) patterns
