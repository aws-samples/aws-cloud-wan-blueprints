<!-- BEGIN_TF_DOCS -->
# Infrastructure-as-Code Patterns — AWS Cloud WAN with traffic inspection (Terraform)

In this pattern, we want to show how AWS Cloud WAN steers traffic through a firewall using service insertion - adding an Inspection VPC with AWS Network Firewall in each Region. Users can test egress (internet-bound) inspection, east-west inspection between segments, and how segment isolation behaves when only some traffic is inspected.

![Inspection architecture](../../../images/2-inspection.png)

See [the pattern README](../README.md) for what this builds, the attachment tags it applies, what its baseline policy configures, and how to verify it.

## Prerequisites

- An AWS account with permissions for Network Manager, Network Firewall, EC2 (VPCs, subnets, instances, endpoints, NAT gateways), and IAM.
- The AWS CLI, configured with credentials.
- Terraform. The minimum version is in the **Requirements** table below.

## Deploy

```bash
cd infra/2-inspection/terraform
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
| <a name="provider_awscc.awsccnvirginia"></a> [awscc.awsccnvirginia](#provider\_awscc.awsccnvirginia) | >= 1.67.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ireland_anfw_policy"></a> [ireland\_anfw\_policy](#module\_ireland\_anfw\_policy) | ../../tf_modules/firewall_policy | n/a |
| <a name="module_ireland_compute"></a> [ireland\_compute](#module\_ireland\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_ireland_inspection_vpc"></a> [ireland\_inspection\_vpc](#module\_ireland\_inspection\_vpc) | aws-ia/cloudwan/aws | = 3.4.0 |
| <a name="module_ireland_spoke_vpcs"></a> [ireland\_spoke\_vpcs](#module\_ireland\_spoke\_vpcs) | aws-ia/vpc/aws | = 4.7.3 |
| <a name="module_nvirginia_anfw_policy"></a> [nvirginia\_anfw\_policy](#module\_nvirginia\_anfw\_policy) | ../../tf_modules/firewall_policy | n/a |
| <a name="module_nvirginia_compute"></a> [nvirginia\_compute](#module\_nvirginia\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_nvirginia_inspection_vpc"></a> [nvirginia\_inspection\_vpc](#module\_nvirginia\_inspection\_vpc) | aws-ia/cloudwan/aws | = 3.4.0 |
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
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project identifier, used as a suffix when naming resources. | `string` | `"inspection"` | no |
| <a name="input_ireland_inspection_vpc"></a> [ireland\_inspection\_vpc](#input\_ireland\_inspection\_vpc) | Information about the Inspection VPC to create in eu-west-1. | <pre>object({<br/>    cidr_block                = string<br/>    number_azs                = number<br/>    public_subnet_netmask     = number<br/>    inspection_subnet_netmask = number<br/>    cnetwork_subnet_netmask   = number<br/>  })</pre> | <pre>{<br/>  "cidr_block": "10.100.0.0/16",<br/>  "cnetwork_subnet_netmask": 28,<br/>  "inspection_subnet_netmask": 28,<br/>  "number_azs": 2,<br/>  "public_subnet_netmask": 28<br/>}</pre> | no |
| <a name="input_ireland_spoke_vpcs"></a> [ireland\_spoke\_vpcs](#input\_ireland\_spoke\_vpcs) | Information about the spoke VPCs to create in eu-west-1. | <pre>map(object({<br/>    segment                 = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    cnetwork_subnet_netmask = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "dev": {<br/>    "cidr_block": "10.0.1.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "development",<br/>    "workload_subnet_netmask": 28<br/>  },<br/>  "prod": {<br/>    "cidr_block": "10.0.0.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "production",<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_nvirginia_inspection_vpc"></a> [nvirginia\_inspection\_vpc](#input\_nvirginia\_inspection\_vpc) | Information about the Inspection VPC to create in us-east-1. | <pre>object({<br/>    cidr_block                = string<br/>    number_azs                = number<br/>    public_subnet_netmask     = number<br/>    inspection_subnet_netmask = number<br/>    cnetwork_subnet_netmask   = number<br/>  })</pre> | <pre>{<br/>  "cidr_block": "10.100.0.0/16",<br/>  "cnetwork_subnet_netmask": 28,<br/>  "inspection_subnet_netmask": 28,<br/>  "number_azs": 2,<br/>  "public_subnet_netmask": 28<br/>}</pre> | no |
| <a name="input_nvirginia_spoke_vpcs"></a> [nvirginia\_spoke\_vpcs](#input\_nvirginia\_spoke\_vpcs) | Information about the spoke VPCs to create in us-east-1. | <pre>map(object({<br/>    segment                 = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    cnetwork_subnet_netmask = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "dev": {<br/>    "cidr_block": "10.10.1.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "development",<br/>    "workload_subnet_netmask": 28<br/>  },<br/>  "prod": {<br/>    "cidr_block": "10.10.0.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "production",<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_policy_document"></a> [policy\_document](#input\_policy\_document) | Path to the Cloud WAN network policy JSON document to deploy. | `string` | `"../baseline.json"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. |
| <a name="output_inspection_vpcs"></a> [inspection\_vpcs](#output\_inspection\_vpcs) | Inspection VPCs created, by Region. |
| <a name="output_spoke_vpcs"></a> [spoke\_vpcs](#output\_spoke\_vpcs) | Spoke VPCs created, by Region. |
<!-- END_TF_DOCS -->