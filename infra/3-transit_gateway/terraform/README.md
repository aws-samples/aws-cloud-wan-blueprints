<!-- BEGIN_TF_DOCS -->
# Infra pattern 3 — Transit Gateway (Terraform)

A Transit Gateway per Region peered with a Cloud WAN core network, with spoke VPCs attached to the Transit Gateway.

See [the pattern README](../README.md) for what this builds, the attachment tags it applies, what its baseline policy demonstrates, and how to verify it. See [`infra/README.md`](../../README.md) for cost, the tagging contract, and how to bring your own policy.

## Prerequisites

- An AWS account with permissions for Network Manager, EC2 (VPCs, subnets, instances, endpoints, Transit Gateways), and IAM.
- The AWS CLI, configured with credentials.
- Terraform. The minimum version is in the **Requirements** table below, which is generated from the code.

## Deploy

```bash
cd infra/3-transit_gateway/terraform
terraform init
terraform plan
terraform apply
```

That deploys the pattern with its working baseline policy, [`../baseline.json`](../baseline.json).

With different Transit Gateway ASNs (they must not overlap the core network `asn-ranges`):

```bash
terraform apply -var 'transit_gateway_asns={nvirginia=64540,ireland=64541}'
```

> **Cost:** an EC2 instance is created in **every** Availability Zone configured for each VPC, so the count grows with the AZ count. For production use at least two AZs. See [Cost](../README.md#cost) for the full breakdown.

## Deploying your own policy

The infrastructure does not change when the policy does — point the variable at your file:

```bash
cd infra/3-transit_gateway/terraform
terraform apply -var policy_document=../../../my-policy.json
```

Your policy must declare `edge-locations` matching `var.aws_regions`, and its `attachment-policies` must match the tags this pattern applies. The validator checks both. A policy that gets either wrong deploys cleanly and moves no traffic.

## Cleanup

```bash
terraform destroy
```

## Next steps

- Add hybrid connectivity: [`../../4-hybrid/`](../../4-hybrid/)
- Share the core network across accounts: [`../../5-multi_account/`](../../5-multi\_account/)
- Learn what else a policy can express: [`policy/`](../../../policy/)

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
| <a name="provider_awscc.awsccnvirginia"></a> [awscc.awsccnvirginia](#provider\_awscc.awsccnvirginia) | 1.95.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ireland_compute"></a> [ireland\_compute](#module\_ireland\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_ireland_spoke_vpcs"></a> [ireland\_spoke\_vpcs](#module\_ireland\_spoke\_vpcs) | aws-ia/vpc/aws | = 4.7.3 |
| <a name="module_ireland_transit_gateway"></a> [ireland\_transit\_gateway](#module\_ireland\_transit\_gateway) | ../../tf_modules/transit_gateway | n/a |
| <a name="module_nvirginia_compute"></a> [nvirginia\_compute](#module\_nvirginia\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_nvirginia_spoke_vpcs"></a> [nvirginia\_spoke\_vpcs](#module\_nvirginia\_spoke\_vpcs) | aws-ia/vpc/aws | = 4.7.3 |
| <a name="module_nvirginia_transit_gateway"></a> [nvirginia\_transit\_gateway](#module\_nvirginia\_transit\_gateway) | ../../tf_modules/transit_gateway | n/a |

## Resources

| Name | Type |
|------|------|
| [awscc_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_core_network) | resource |
| [awscc_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_global_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_regions"></a> [aws\_regions](#input\_aws\_regions) | AWS Regions to create the environment. Must match the edge-locations in the policy document. | `map(string)` | <pre>{<br/>  "ireland": "eu-west-1",<br/>  "nvirginia": "us-east-1"<br/>}</pre> | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project identifier, used as a suffix when naming resources. | `string` | `"transit-gateway"` | no |
| <a name="input_ireland_spoke_vpcs"></a> [ireland\_spoke\_vpcs](#input\_ireland\_spoke\_vpcs) | Information about the spoke VPCs to create in eu-west-1. | <pre>map(object({<br/>    route_table             = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    tgw_subnet_netmask      = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "dev": {<br/>    "cidr_block": "10.0.1.0/24",<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "route_table": "development",<br/>    "tgw_subnet_netmask": 28,<br/>    "workload_subnet_netmask": 28<br/>  },<br/>  "prod": {<br/>    "cidr_block": "10.0.0.0/24",<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "route_table": "production",<br/>    "tgw_subnet_netmask": 28,<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_nvirginia_spoke_vpcs"></a> [nvirginia\_spoke\_vpcs](#input\_nvirginia\_spoke\_vpcs) | Information about the spoke VPCs to create in us-east-1. | <pre>map(object({<br/>    route_table             = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    tgw_subnet_netmask      = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "dev": {<br/>    "cidr_block": "10.10.1.0/24",<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "route_table": "development",<br/>    "tgw_subnet_netmask": 28,<br/>    "workload_subnet_netmask": 28<br/>  },<br/>  "prod": {<br/>    "cidr_block": "10.10.0.0/24",<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "route_table": "production",<br/>    "tgw_subnet_netmask": 28,<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_policy_document"></a> [policy\_document](#input\_policy\_document) | Path to the Cloud WAN network policy JSON document to deploy. | `string` | `"../baseline.json"` | no |
| <a name="input_route_tables"></a> [route\_tables](#input\_route\_tables) | Transit Gateway route tables to create in each Region: name => Cloud WAN segment. | `map(string)` | <pre>{<br/>  "development": "development",<br/>  "production": "production"<br/>}</pre> | no |
| <a name="input_transit_gateway_asns"></a> [transit\_gateway\_asns](#input\_transit\_gateway\_asns) | Amazon-side ASN for the Transit Gateway in each Region. | `map(number)` | <pre>{<br/>  "ireland": 64533,<br/>  "nvirginia": 64532<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. |
| <a name="output_cloud_wan_route_table_attachments"></a> [cloud\_wan\_route\_table\_attachments](#output\_cloud\_wan\_route\_table\_attachments) | Cloud WAN transit-gateway-route-table attachments, by Region and route table. |
| <a name="output_policy_document"></a> [policy\_document](#output\_policy\_document) | Path to the Cloud WAN network policy document deployed. |
| <a name="output_spoke_vpcs"></a> [spoke\_vpcs](#output\_spoke\_vpcs) | Spoke VPCs created, by Region. |
| <a name="output_transit_gateways"></a> [transit\_gateways](#output\_transit\_gateways) | Transit Gateways created, by Region. |
<!-- END_TF_DOCS -->