<!-- BEGIN_TF_DOCS -->
# AWS Cloud WAN Hybrid Path Influence (Terraform)

![Hybrid Path Influence](../../../../images/patterns\_filtering\_bgp\_community.png)

> **⚠️ Hybrid Environment Required**: This pattern requires you to establish two hybrid connections (Site-to-Site VPN or Connect attachments) in different AWS regions, both announcing the same route prefix. The IaC code creates the Cloud WAN infrastructure, but you must configure your on-premises routers to establish BGP sessions and advertise routes.

## Prerequisites

- **AWS Account**: With appropriate IAM permissions
- **Terraform**: >= 1.3.0 installed
- **AWS CLI**: Configured with credentials (optional, for verification)
- **Permissions required**:
  - Network Manager
  - EC2: VPC, subnets, instances, endpoints
  - IAM: Create roles and policies
- **Hybrid Connectivity**: Two Site-to-Site VPN or Connect attachments in different regions

## Deployment

```bash
# Clone the repository
git clone https://github.com/aws-samples/aws-cloud-wan-blueprints.git

# Navigate to the Terraform directory
cd patterns/4-routing_policies/5-influencing_hybrid_path_between_cnes/terraform

# Initialize Terraform
terraform init

# (Optional) Review the planned changes
terraform plan

# Deploy the resources
terraform apply
```

> **Note**: For end-to-end testing, establish hybrid connections in us-east-1 (ASN 65052) and eu-west-2 (ASN 65058) announcing the same route - you will need to change ASN values in the Core Network policy if you want to use other values. EC2 instances will be deployed in all the Availability Zones configured for each VPC. Keep this in mind when testing this environment from a cost perspective - for production environments, we recommend the use of at least 2 AZs for high-availability.

## Cleanup

```bash
# Destroy all resources
terraform destroy
```

## Next Steps

After successfully deploying this pattern:

1. **Explore the architecture**: Review routing policies and CNE-to-CNE associations in Network Manager console
2. **Test connectivity**: Establish hybrid connectivity and verify path selection via AS-PATH manipulation
3. **Try modifications**: Adjust AS-PATH prepending, test different region pairs

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.34.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | 1.73.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ireland_compute"></a> [ireland\_compute](#module\_ireland\_compute) | ../../../tf_modules/compute | n/a |
| <a name="module_ireland_spoke_vpc"></a> [ireland\_spoke\_vpc](#module\_ireland\_spoke\_vpc) | aws-ia/vpc/aws | = 4.7.3 |
| <a name="module_london_compute"></a> [london\_compute](#module\_london\_compute) | ../../../tf_modules/compute | n/a |
| <a name="module_london_spoke_vpc"></a> [london\_spoke\_vpc](#module\_london\_spoke\_vpc) | aws-ia/vpc/aws | = 4.7.3 |
| <a name="module_nvirginia_compute"></a> [nvirginia\_compute](#module\_nvirginia\_compute) | ../../../tf_modules/compute | n/a |
| <a name="module_nvirginia_spoke_vpc"></a> [nvirginia\_spoke\_vpc](#module\_nvirginia\_spoke\_vpc) | aws-ia/vpc/aws | = 4.7.3 |

## Resources

| Name | Type |
|------|------|
| [awscc_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_core_network) | resource |
| [awscc_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_global_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_regions"></a> [aws\_regions](#input\_aws\_regions) | AWS Regions to create the environment. | `map(string)` | <pre>{<br/>  "ireland": "eu-west-1",<br/>  "london": "eu-west-2",<br/>  "nvirginia": "us-east-1"<br/>}</pre> | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project Identifier, used as identifer when creating resources. | `string` | `"influencing-hybrid-between-cnes"` | no |
| <a name="input_ireland_spoke_vpc"></a> [ireland\_spoke\_vpc](#input\_ireland\_spoke\_vpc) | Information about the VPC to create in eu-west-1. | `map(any)` | <pre>{<br/>  "cidr_block": "10.0.0.0/24",<br/>  "cnetwork_subnet_netmask": 28,<br/>  "endpoint_subnet_netmask": 28,<br/>  "instance_type": "t2.micro",<br/>  "name": "vpc-eu-west-1",<br/>  "number_azs": 2,<br/>  "workload_subnet_netmask": 28<br/>}</pre> | no |
| <a name="input_london_spoke_vpc"></a> [london\_spoke\_vpc](#input\_london\_spoke\_vpc) | Information about the VPC to create in eu-west-2. | `map(any)` | <pre>{<br/>  "cidr_block": "10.20.0.0/24",<br/>  "cnetwork_subnet_netmask": 28,<br/>  "endpoint_subnet_netmask": 28,<br/>  "instance_type": "t2.micro",<br/>  "name": "vpc-eu-west-2",<br/>  "number_azs": 2,<br/>  "workload_subnet_netmask": 28<br/>}</pre> | no |
| <a name="input_nvirginia_spoke_vpc"></a> [nvirginia\_spoke\_vpc](#input\_nvirginia\_spoke\_vpc) | Information about the VPC to create in us-east-1. | `map(any)` | <pre>{<br/>  "cidr_block": "10.10.0.0/24",<br/>  "cnetwork_subnet_netmask": 28,<br/>  "endpoint_subnet_netmask": 28,<br/>  "instance_type": "t2.micro",<br/>  "name": "vpc-us-east-1",<br/>  "number_azs": 2,<br/>  "workload_subnet_netmask": 28<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. |
| <a name="output_vpcs"></a> [vpcs](#output\_vpcs) | VPCs created. |
<!-- END_TF_DOCS -->