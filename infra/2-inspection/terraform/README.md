<!-- BEGIN_TF_DOCS -->
# Infra pattern 2 — Inspection (Terraform)

Spoke VPCs plus an inspection VPC with AWS Network Firewall per Region, attached to a Cloud WAN network function group.

See [the pattern README](../README.md) for what this builds, the attachment tags it applies, what its baseline policy demonstrates, and how to verify it. See [`infra/README.md`](../../README.md) for cost, the tagging contract, and how to bring your own policy.

## Prerequisites

- An AWS account with permissions for Network Manager, Network Firewall, EC2 (VPCs, subnets, instances, endpoints, NAT gateways), and IAM.
- The AWS CLI, configured with credentials.
- Terraform. The minimum version is in the **Requirements** table below, which is generated from the code.

## Deploy

```bash
cd infra/2-inspection/terraform
terraform init
terraform plan
terraform apply
```

That deploys the pattern with its working baseline policy, [`../baseline.json`](../baseline.json).

With the optional secondary CIDR blocks, and the filter-then-inspect example policy:

```bash
terraform apply -var create_secondary_cidrs=true -var policy_document=../../../policy/examples/filter_then_inspect.json
```

> **Cost:** an EC2 instance is created in **every** Availability Zone configured for each VPC, so the count grows with the AZ count. For production use at least two AZs. See [Cost](../README.md#cost) for the full breakdown.

## Deploying your own policy

The infrastructure does not change when the policy does — point the variable at your file:

```bash
cd infra/2-inspection/terraform
terraform apply -var policy_document=../../../my-policy.json
```

Your policy must declare `edge-locations` matching `var.aws_regions`, and its `attachment-policies` must match the tags this pattern applies. The validator checks both. A policy that gets either wrong deploys cleanly and moves no traffic.

## Cleanup

```bash
terraform destroy
```

## Next steps

- Integrate a Transit Gateway: [`../../3-transit_gateway/`](../../3-transit\_gateway/)
- Add hybrid connectivity: [`../../4-hybrid/`](../../4-hybrid/)
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
| <a name="module_ireland_anfw_policy"></a> [ireland\_anfw\_policy](#module\_ireland\_anfw\_policy) | ../../tf_modules/firewall_policy | n/a |
| <a name="module_ireland_compute"></a> [ireland\_compute](#module\_ireland\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_ireland_inspection_vpc"></a> [ireland\_inspection\_vpc](#module\_ireland\_inspection\_vpc) | aws-ia/cloudwan/aws | = 3.4.0 |
| <a name="module_ireland_secondary_cidrs"></a> [ireland\_secondary\_cidrs](#module\_ireland\_secondary\_cidrs) | aws-ia/vpc/aws | = 4.7.3 |
| <a name="module_ireland_spoke_vpcs"></a> [ireland\_spoke\_vpcs](#module\_ireland\_spoke\_vpcs) | aws-ia/vpc/aws | = 4.7.3 |
| <a name="module_nvirginia_anfw_policy"></a> [nvirginia\_anfw\_policy](#module\_nvirginia\_anfw\_policy) | ../../tf_modules/firewall_policy | n/a |
| <a name="module_nvirginia_compute"></a> [nvirginia\_compute](#module\_nvirginia\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_nvirginia_inspection_vpc"></a> [nvirginia\_inspection\_vpc](#module\_nvirginia\_inspection\_vpc) | aws-ia/cloudwan/aws | = 3.4.0 |
| <a name="module_nvirginia_secondary_cidrs"></a> [nvirginia\_secondary\_cidrs](#module\_nvirginia\_secondary\_cidrs) | aws-ia/vpc/aws | = 4.7.3 |
| <a name="module_nvirginia_spoke_vpcs"></a> [nvirginia\_spoke\_vpcs](#module\_nvirginia\_spoke\_vpcs) | aws-ia/vpc/aws | = 4.7.3 |

## Resources

| Name | Type |
|------|------|
| [awscc_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_core_network) | resource |
| [awscc_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_global_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_regions"></a> [aws\_regions](#input\_aws\_regions) | AWS Regions to create the environment. Must match the edge-locations in the policy document. | `map(string)` | <pre>{<br/>  "ireland": "eu-west-1",<br/>  "nvirginia": "us-east-1"<br/>}</pre> | no |
| <a name="input_create_secondary_cidrs"></a> [create\_secondary\_cidrs](#input\_create\_secondary\_cidrs) | Add a secondary IPv4 CIDR block to each spoke VPC. Needed by the filter\_then\_inspect example. | `bool` | `false` | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project identifier, used as a suffix when naming resources. | `string` | `"inspection"` | no |
| <a name="input_ireland_inspection_vpc"></a> [ireland\_inspection\_vpc](#input\_ireland\_inspection\_vpc) | Information about the Inspection VPC to create in eu-west-1. | <pre>object({<br/>    cidr_block                = string<br/>    number_azs                = number<br/>    public_subnet_netmask     = number<br/>    inspection_subnet_netmask = number<br/>    cnetwork_subnet_netmask   = number<br/>  })</pre> | <pre>{<br/>  "cidr_block": "10.100.0.0/16",<br/>  "cnetwork_subnet_netmask": 28,<br/>  "inspection_subnet_netmask": 28,<br/>  "number_azs": 2,<br/>  "public_subnet_netmask": 28<br/>}</pre> | no |
| <a name="input_ireland_spoke_vpcs"></a> [ireland\_spoke\_vpcs](#input\_ireland\_spoke\_vpcs) | Information about the spoke VPCs to create in eu-west-1. | <pre>map(object({<br/>    segment                 = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    cnetwork_subnet_netmask = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "dev": {<br/>    "cidr_block": "10.0.1.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "development",<br/>    "workload_subnet_netmask": 28<br/>  },<br/>  "prod": {<br/>    "cidr_block": "10.0.0.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "production",<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_nvirginia_inspection_vpc"></a> [nvirginia\_inspection\_vpc](#input\_nvirginia\_inspection\_vpc) | Information about the Inspection VPC to create in us-east-1. | <pre>object({<br/>    cidr_block                = string<br/>    number_azs                = number<br/>    public_subnet_netmask     = number<br/>    inspection_subnet_netmask = number<br/>    cnetwork_subnet_netmask   = number<br/>  })</pre> | <pre>{<br/>  "cidr_block": "10.100.0.0/16",<br/>  "cnetwork_subnet_netmask": 28,<br/>  "inspection_subnet_netmask": 28,<br/>  "number_azs": 2,<br/>  "public_subnet_netmask": 28<br/>}</pre> | no |
| <a name="input_nvirginia_spoke_vpcs"></a> [nvirginia\_spoke\_vpcs](#input\_nvirginia\_spoke\_vpcs) | Information about the spoke VPCs to create in us-east-1. | <pre>map(object({<br/>    segment                 = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    cnetwork_subnet_netmask = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "dev": {<br/>    "cidr_block": "10.10.1.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "development",<br/>    "workload_subnet_netmask": 28<br/>  },<br/>  "prod": {<br/>    "cidr_block": "10.10.0.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "production",<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_policy_document"></a> [policy\_document](#input\_policy\_document) | Path to the Cloud WAN network policy JSON document to deploy. | `string` | `"../baseline.json"` | no |
| <a name="input_secondary_cidr_blocks"></a> [secondary\_cidr\_blocks](#input\_secondary\_cidr\_blocks) | Secondary IPv4 CIDR block per Region, and the subnet netmask to carve from it. | <pre>object({<br/>    nvirginia = string<br/>    ireland   = string<br/>    netmask   = number<br/>  })</pre> | <pre>{<br/>  "ireland": "100.65.0.0/16",<br/>  "netmask": 28,<br/>  "nvirginia": "100.64.0.0/16"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. |
| <a name="output_inspection_vpcs"></a> [inspection\_vpcs](#output\_inspection\_vpcs) | Inspection VPCs created, by Region. |
| <a name="output_policy_document"></a> [policy\_document](#output\_policy\_document) | Path to the Cloud WAN network policy document deployed. |
| <a name="output_spoke_vpcs"></a> [spoke\_vpcs](#output\_spoke\_vpcs) | Spoke VPCs created, by Region. |
<!-- END_TF_DOCS -->