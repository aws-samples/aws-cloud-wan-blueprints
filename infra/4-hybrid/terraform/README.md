<!-- BEGIN_TF_DOCS -->
# Infrastructure-as-Code Patterns — AWS Cloud WAN with hybrid connectivity (Terraform)

In this pattern, we want to show how AWS Cloud WAN integrates with AWS Site-to-Site VPN and AWS Direct Connect to achieve hybrid connectivity.

<!-- DIAGRAM PLACEHOLDER -->
> \_Architecture diagram to be added.\_

See [the pattern README](../README.md) for what this builds, how its attachments associate, what its baseline policy configures, and how to verify it.

## Prerequisites

- An AWS account with permissions for Network Manager, EC2 (VPCs, subnets, instances, endpoints, customer gateways, VPN connections), Direct Connect, and IAM.
- The AWS CLI, configured with credentials.
- Terraform. The minimum version is in the **Requirements** table below.

## Deploy

```bash
cd infra/4-hybrid/terraform
terraform init
terraform plan
terraform apply
```

That deploys the pattern with its working baseline policy, [`../baseline.json`](../baseline.json): the core network and one spoke VPC per Region. Both hybrid attachments are off by default — enable either or both. Neither ASN may overlap the core network's `asn-ranges`, which the baseline sets to `64520-64525`.

The Site-to-Site VPN is created in `us-east-1`. Both values describe your on-premises device, so there is no default for them:

```bash
terraform apply -var 'site_to_site_vpn={customer_gateway_ip="203.0.113.10",customer_gateway_asn=65010}'
```

The Direct Connect gateway needs only its Amazon-side ASN:

```bash
terraform apply -var 'direct_connect_gateway={amazon_side_asn=64534}'
```

> **This pattern builds the AWS side only.** The VPN tunnels stay down until a real on-premises peer answers, and the Direct Connect gateway carries no traffic until you associate a Transit VIF with it — creating the Transit VIFs and their association is out of scope here. What you can verify is the integration itself: that each hybrid attachment reaches the `hybrid` segment. Testing the path end to end is yours to do.

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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.58.0 |
| <a name="provider_aws.awsnvirginia"></a> [aws.awsnvirginia](#provider\_aws.awsnvirginia) | 6.58.0 |
| <a name="provider_awscc.awsccnvirginia"></a> [awscc.awsccnvirginia](#provider\_awscc.awsccnvirginia) | 1.95.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ireland_compute"></a> [ireland\_compute](#module\_ireland\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_ireland_spoke_vpc"></a> [ireland\_spoke\_vpc](#module\_ireland\_spoke\_vpc) | aws-ia/vpc/aws | = 4.7.3 |
| <a name="module_nvirginia_compute"></a> [nvirginia\_compute](#module\_nvirginia\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_nvirginia_spoke_vpc"></a> [nvirginia\_spoke\_vpc](#module\_nvirginia\_spoke\_vpc) | aws-ia/vpc/aws | = 4.7.3 |

## Resources

| Name | Type |
|------|------|
| [aws_customer_gateway.cgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/customer_gateway) | resource |
| [aws_dx_gateway.dxgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dx_gateway) | resource |
| [aws_networkmanager_dx_gateway_attachment.dxgw_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_dx_gateway_attachment) | resource |
| [aws_networkmanager_site_to_site_vpn_attachment.vpn_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_site_to_site_vpn_attachment) | resource |
| [aws_vpn_connection.vpn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection) | resource |
| [awscc_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_core_network) | resource |
| [awscc_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_global_network) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_regions"></a> [aws\_regions](#input\_aws\_regions) | AWS Regions to create the environment. nvirginia and ireland must match the edge-locations in the policy document. | `map(string)` | <pre>{<br/>  "ireland": "eu-west-1",<br/>  "nvirginia": "us-east-1"<br/>}</pre> | no |
| <a name="input_direct_connect_gateway"></a> [direct\_connect\_gateway](#input\_direct\_connect\_gateway) | Direct Connect gateway configuration. The Amazon-side ASN must not overlap the asn-ranges in the policy document. null to skip. | <pre>object({<br/>    amazon_side_asn = number<br/>  })</pre> | `null` | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project identifier, used as a suffix when naming resources. | `string` | `"hybrid"` | no |
| <a name="input_ireland_spoke_vpc"></a> [ireland\_spoke\_vpc](#input\_ireland\_spoke\_vpc) | Information about the spoke VPC to create in eu-west-1. | <pre>object({<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    cnetwork_subnet_netmask = number<br/>    instance_type           = string<br/>  })</pre> | <pre>{<br/>  "cidr_block": "10.0.0.0/24",<br/>  "cnetwork_subnet_netmask": 28,<br/>  "endpoint_subnet_netmask": 28,<br/>  "instance_type": "t2.micro",<br/>  "number_azs": 2,<br/>  "workload_subnet_netmask": 28<br/>}</pre> | no |
| <a name="input_nvirginia_spoke_vpc"></a> [nvirginia\_spoke\_vpc](#input\_nvirginia\_spoke\_vpc) | Information about the spoke VPC to create in us-east-1. | <pre>object({<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    cnetwork_subnet_netmask = number<br/>    instance_type           = string<br/>  })</pre> | <pre>{<br/>  "cidr_block": "10.10.0.0/24",<br/>  "cnetwork_subnet_netmask": 28,<br/>  "endpoint_subnet_netmask": 28,<br/>  "instance_type": "t2.micro",<br/>  "number_azs": 2,<br/>  "workload_subnet_netmask": 28<br/>}</pre> | no |
| <a name="input_policy_document"></a> [policy\_document](#input\_policy\_document) | Path to the Cloud WAN network policy JSON document to deploy. | `string` | `"../baseline.json"` | no |
| <a name="input_site_to_site_vpn"></a> [site\_to\_site\_vpn](#input\_site\_to\_site\_vpn) | Site-to-Site VPN configuration, created in us-east-1. The customer gateway ASN must not overlap the asn-ranges in the policy document. null to skip. | <pre>object({<br/>    customer_gateway_ip  = string<br/>    customer_gateway_asn = number<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. |
| <a name="output_hybrid_attachments"></a> [hybrid\_attachments](#output\_hybrid\_attachments) | Hybrid attachments created. A null entry is a sub-type that was not enabled. |
| <a name="output_spoke_vpcs"></a> [spoke\_vpcs](#output\_spoke\_vpcs) | Spoke VPC created in each Region. |
<!-- END_TF_DOCS -->