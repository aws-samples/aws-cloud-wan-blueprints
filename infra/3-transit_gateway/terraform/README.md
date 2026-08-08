<!-- BEGIN_TF_DOCS -->
# Infrastructure-as-Code Patterns — AWS Cloud WAN with AWS Transit Gateway (Terraform)

In this pattern, we want to show how AWS Cloud WAN connects to AWS Transit Gateway using a peering connection - and how segmentation can be configured on top of that peering. Users can test global traffic segmentation, communication between segments, and segment isolation for workloads that reach the core network through a Transit Gateway.

<!-- DIAGRAM PLACEHOLDER -->
> \_Architecture diagram to be added.\_

See [the pattern README](../README.md) for what this builds, the attachment tags it applies, what its baseline policy configures, and how to verify it.

## Prerequisites

- An AWS account with permissions for Network Manager, EC2 (VPCs, subnets, instances, endpoints, Transit Gateways), and IAM.
- The AWS CLI, configured with credentials.
- Terraform. The minimum version is in the **Requirements** table below.

## Deploy

```bash
cd infra/3-transit_gateway/terraform
terraform init
terraform plan
terraform apply
```

That deploys the pattern with its working baseline policy, [`../baseline.json`](../baseline.json).

> **Using a policy of your own?** No Terraform changes needed — `main.tf` reads whatever file `var.policy_document` points at. Drop your document in the pattern folder next to the baseline, then `terraform apply -var policy_document=../my-policy.json`. Paths are relative to this directory, which is why the default is `../baseline.json`; change that default in `variables.tf` to stop passing `-var` every time.

## Cleanup

```bash
terraform destroy
```

---

Everything below is generated from the Terraform source by `terraform-docs`. Do not edit `README.md` directly — edit [`.header.md`](./.header.md) and regenerate.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.34.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.67.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws.awsireland"></a> [aws.awsireland](#provider\_aws.awsireland) | 6.58.0 |
| <a name="provider_aws.awsnvirginia"></a> [aws.awsnvirginia](#provider\_aws.awsnvirginia) | 6.58.0 |
| <a name="provider_awscc.awsccnvirginia"></a> [awscc.awsccnvirginia](#provider\_awscc.awsccnvirginia) | 1.95.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ireland_compute"></a> [ireland\_compute](#module\_ireland\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_ireland_spoke_vpcs"></a> [ireland\_spoke\_vpcs](#module\_ireland\_spoke\_vpcs) | aws-ia/vpc/aws | = 4.7.3 |
| <a name="module_nvirginia_compute"></a> [nvirginia\_compute](#module\_nvirginia\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_nvirginia_spoke_vpcs"></a> [nvirginia\_spoke\_vpcs](#module\_nvirginia\_spoke\_vpcs) | aws-ia/vpc/aws | = 4.7.3 |

## Resources

| Name | Type |
|------|------|
| [aws_ec2_transit_gateway.ireland_transit_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway) | resource |
| [aws_ec2_transit_gateway.nvirginia_transit_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway) | resource |
| [aws_ec2_transit_gateway_policy_table.ireland_tgw_policy_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_policy_table) | resource |
| [aws_ec2_transit_gateway_policy_table.nvirginia_tgw_policy_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_policy_table) | resource |
| [aws_ec2_transit_gateway_policy_table_association.ireland_tgw_policy_table_assoc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_policy_table_association) | resource |
| [aws_ec2_transit_gateway_policy_table_association.nvirginia_tgw_policy_table_assoc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_policy_table_association) | resource |
| [aws_ec2_transit_gateway_route_table.ireland_tgw_development_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ec2_transit_gateway_route_table.ireland_tgw_production_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ec2_transit_gateway_route_table.nvirginia_tgw_development_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ec2_transit_gateway_route_table.nvirginia_tgw_production_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ec2_transit_gateway_route_table_association.ireland_tgw_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_association) | resource |
| [aws_ec2_transit_gateway_route_table_association.nvirginia_tgw_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_association) | resource |
| [aws_ec2_transit_gateway_route_table_propagation.ireland_tgw_propagation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_propagation) | resource |
| [aws_ec2_transit_gateway_route_table_propagation.nvirginia_tgw_propagation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_propagation) | resource |
| [aws_networkmanager_transit_gateway_peering.ireland_tgw_cwan_peering](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_transit_gateway_peering) | resource |
| [aws_networkmanager_transit_gateway_peering.nvirginia_tgw_cwan_peering](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_transit_gateway_peering) | resource |
| [aws_networkmanager_transit_gateway_route_table_attachment.ireland_development_rt_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_transit_gateway_route_table_attachment) | resource |
| [aws_networkmanager_transit_gateway_route_table_attachment.ireland_production_rt_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_transit_gateway_route_table_attachment) | resource |
| [aws_networkmanager_transit_gateway_route_table_attachment.nvirginia_development_rt_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_transit_gateway_route_table_attachment) | resource |
| [aws_networkmanager_transit_gateway_route_table_attachment.nvirginia_production_rt_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_transit_gateway_route_table_attachment) | resource |
| [awscc_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_core_network) | resource |
| [awscc_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_global_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_regions"></a> [aws\_regions](#input\_aws\_regions) | AWS Regions to create the environment. Must match the edge-locations in the policy document. | `map(string)` | <pre>{<br/>  "ireland": "eu-west-1",<br/>  "nvirginia": "us-east-1"<br/>}</pre> | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project identifier, used as a suffix when naming resources. | `string` | `"transit-gateway"` | no |
| <a name="input_ireland_spoke_vpcs"></a> [ireland\_spoke\_vpcs](#input\_ireland\_spoke\_vpcs) | Information about the spoke VPCs to create in eu-west-1. | <pre>map(object({<br/>    segment                 = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    tgw_subnet_netmask      = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "dev": {<br/>    "cidr_block": "10.0.1.0/24",<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "development",<br/>    "tgw_subnet_netmask": 28,<br/>    "workload_subnet_netmask": 28<br/>  },<br/>  "prod": {<br/>    "cidr_block": "10.0.0.0/24",<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "production",<br/>    "tgw_subnet_netmask": 28,<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_nvirginia_spoke_vpcs"></a> [nvirginia\_spoke\_vpcs](#input\_nvirginia\_spoke\_vpcs) | Information about the spoke VPCs to create in us-east-1. | <pre>map(object({<br/>    segment                 = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    tgw_subnet_netmask      = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "dev": {<br/>    "cidr_block": "10.10.1.0/24",<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "development",<br/>    "tgw_subnet_netmask": 28,<br/>    "workload_subnet_netmask": 28<br/>  },<br/>  "prod": {<br/>    "cidr_block": "10.10.0.0/24",<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "production",<br/>    "tgw_subnet_netmask": 28,<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_policy_document"></a> [policy\_document](#input\_policy\_document) | Path to the Cloud WAN network policy JSON document to deploy. | `string` | `"../baseline.json"` | no |
| <a name="input_transit_gateway_asns"></a> [transit\_gateway\_asns](#input\_transit\_gateway\_asns) | Amazon-side ASN for the Transit Gateway in each Region. Must not overlap the asn-ranges in the policy document. | `map(number)` | <pre>{<br/>  "ireland": 64533,<br/>  "nvirginia": 64532<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. |
| <a name="output_cloud_wan_peerings"></a> [cloud\_wan\_peerings](#output\_cloud\_wan\_peerings) | Transit Gateway peerings with the core network, by Region. |
| <a name="output_cloud_wan_route_table_attachments"></a> [cloud\_wan\_route\_table\_attachments](#output\_cloud\_wan\_route\_table\_attachments) | Cloud WAN transit-gateway-route-table attachments, by Region and segment. |
| <a name="output_spoke_vpcs"></a> [spoke\_vpcs](#output\_spoke\_vpcs) | Spoke VPCs created, by Region. |
| <a name="output_transit_gateway_route_tables"></a> [transit\_gateway\_route\_tables](#output\_transit\_gateway\_route\_tables) | Transit Gateway route tables created, by Region and segment. |
| <a name="output_transit_gateways"></a> [transit\_gateways](#output\_transit\_gateways) | Transit Gateways created, by Region. |
<!-- END_TF_DOCS -->