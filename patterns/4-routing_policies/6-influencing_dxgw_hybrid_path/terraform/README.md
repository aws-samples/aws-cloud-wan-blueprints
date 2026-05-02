<!-- BEGIN_TF_DOCS -->
# AWS Cloud WAN Direct Connect Gateway (DXGW) Path Influence (Terraform)

![Influencing DXGW hybrid path](../../../../images/patterns\_influencing\_dxgw\_hybrid\_path.png)

> **⚠️ Hybrid Environment Required**: This pattern requires you to establish Direct Connect connections and Virtual Interfaces (VIFs) through two Direct Connect Gateways (DXGWs) in different geographical locations, both announcing the same route prefix. The IaC code creates the Cloud WAN infrastructure and DXGWs, but you must configure your on-premises routers to establish BGP sessions and advertise routes.

## Prerequisites

- **AWS Account**: With appropriate IAM permissions
- **Terraform**: >= 1.3.0 installed
- **AWS CLI**: Configured with credentials (optional, for verification)
- **Permissions required**:
  - Network Manager
  - EC2: VPC, subnets, instances, endpoints
  - IAM: Create roles and policies
  - Direct Connect: Create and manage Direct Connect Gateways
- **Hybrid Connectivity**: Direct Connect connections through two DXGWs in different regions

## Deployment

```bash
# Clone the repository
git clone https://github.com/aws-samples/aws-cloud-wan-blueprints.git

# Navigate to the Terraform directory
cd patterns/4-routing_policies/6-influencing_dxgw_hybrid_path/terraform

# Initialize Terraform
terraform init

# (Optional) Review the planned changes
terraform plan

# Deploy the resources
terraform apply
```

> **Note**: For end-to-end testing, establish Direct Connect connections and VIFs through the Europe DXGW (ASN 64512) and US DXGW (ASN 64513) announcing the same route - you will need to change ASN values in the Core Network policy if you want to use other values. EC2 instances will be deployed in all the Availability Zones configured for each VPC. Keep this in mind when testing this environment from a cost perspective - for production environments, we recommend the use of at least 2 AZs for high-availability.

## Cleanup

```bash
# Destroy all resources
terraform destroy
```

## Next Steps

After successfully deploying this pattern:

1. **Explore the architecture**: Review routing policies and segment sharing in Network Manager console.
2. **Test connectivity**: Establish Direct Connect connections and verify path selection via AS-PATH manipulation.
3. **Try modifications**: Adjust AS-PATH prepending, test different DXGW configurations.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.33.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.26.0 |
| <a name="provider_aws.awsireland"></a> [aws.awsireland](#provider\_aws.awsireland) | 6.26.0 |
| <a name="provider_aws.awsnvirginia"></a> [aws.awsnvirginia](#provider\_aws.awsnvirginia) | 6.26.0 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | 1.66.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ireland_compute"></a> [ireland\_compute](#module\_ireland\_compute) | ../../../tf_modules/compute | n/a |
| <a name="module_ireland_spoke_vpc"></a> [ireland\_spoke\_vpc](#module\_ireland\_spoke\_vpc) | aws-ia/vpc/aws | = 4.7.3 |
| <a name="module_nvirginia_compute"></a> [nvirginia\_compute](#module\_nvirginia\_compute) | ../../../tf_modules/compute | n/a |
| <a name="module_nvirginia_spoke_vpc"></a> [nvirginia\_spoke\_vpc](#module\_nvirginia\_spoke\_vpc) | aws-ia/vpc/aws | = 4.7.3 |

## Resources

| Name | Type |
|------|------|
| [aws_dx_gateway.europe_dxgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dx_gateway) | resource |
| [aws_dx_gateway.us_dxgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dx_gateway) | resource |
| [aws_networkmanager_dx_gateway_attachment.europe_dxgw_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_dx_gateway_attachment) | resource |
| [aws_networkmanager_dx_gateway_attachment.us_dxgw_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_dx_gateway_attachment) | resource |
| [awscc_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_core_network) | resource |
| [awscc_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_global_network) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_regions"></a> [aws\_regions](#input\_aws\_regions) | AWS Regions to create the environment. | `map(string)` | <pre>{<br/>  "ireland": "eu-west-1",<br/>  "nvirginia": "us-east-1"<br/>}</pre> | no |
| <a name="input_dxgw_asns"></a> [dxgw\_asns](#input\_dxgw\_asns) | Direct Connect gateway ASNs | `map(string)` | <pre>{<br/>  "europe": "64512",<br/>  "us": "64513"<br/>}</pre> | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project Identifier, used as identifer when creating resources. | `string` | `"influencing-dxgw-hybrid-path"` | no |
| <a name="input_ireland_spoke_vpc"></a> [ireland\_spoke\_vpc](#input\_ireland\_spoke\_vpc) | Information about the VPC to create in eu-west-1. | `map(any)` | <pre>{<br/>  "cidr_block": "10.0.0.0/24",<br/>  "cnetwork_subnet_netmask": 28,<br/>  "endpoint_subnet_netmask": 28,<br/>  "instance_type": "t2.micro",<br/>  "name": "vpc-eu-west-1",<br/>  "number_azs": 2,<br/>  "workload_subnet_netmask": 28<br/>}</pre> | no |
| <a name="input_nvirginia_spoke_vpc"></a> [nvirginia\_spoke\_vpc](#input\_nvirginia\_spoke\_vpc) | Information about the VPC to create in us-east-1. | `map(any)` | <pre>{<br/>  "cidr_block": "10.10.0.0/24",<br/>  "cnetwork_subnet_netmask": 28,<br/>  "endpoint_subnet_netmask": 28,<br/>  "instance_type": "t2.micro",<br/>  "name": "vpc-us-east-1",<br/>  "number_azs": 2,<br/>  "workload_subnet_netmask": 28<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. |
| <a name="output_vpcs"></a> [vpcs](#output\_vpcs) | VPCs created. |
<!-- END_TF_DOCS -->