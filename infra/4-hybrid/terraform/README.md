<!-- BEGIN_TF_DOCS -->
# Infra pattern 4 — Hybrid (Terraform)

Spoke VPCs plus optional Site-to-Site VPN, Connect, and Direct Connect gateway attachments, and managed prefix lists for route summarization.

See [the pattern README](../README.md) for what this builds, the attachment tags it applies, what its baseline policy demonstrates, and how to verify it. See [`infra/README.md`](../../README.md) for cost, the tagging contract, and how to bring your own policy.

## Prerequisites

- An AWS account with permissions for Network Manager, EC2 (VPCs, subnets, instances, endpoints, VPN, managed prefix lists), Direct Connect, and IAM.
- The AWS CLI, configured with credentials.
- Terraform. The minimum version is in the **Requirements** table below, which is generated from the code.

## Deploy

```bash
cd infra/4-hybrid/terraform
terraform init
terraform plan
terraform apply
```

That deploys the pattern with its working baseline policy, [`../baseline.json`](../baseline.json).

With a Site-to-Site VPN:

```bash
terraform apply -var 'site_to_site_vpn={customer_gateway_ip="203.0.113.10",customer_gateway_asn=65010,region="us-east-1"}'
```

With a Direct Connect gateway:

```bash
terraform apply -var 'direct_connect_gateway={amazon_side_asn=64532}'
```

Without the managed prefix lists:

```bash
terraform apply -var create_prefix_lists=false
```

Hybrid ASNs must not overlap the core network's `asn-ranges` (`64520-64525` in the baseline), and that range is **right-open** — it provides 64520 to 64524.

> **Cost:** an EC2 instance is created in **every** Availability Zone configured for each VPC, so the count grows with the AZ count. For production use at least two AZs. See [Cost](../README.md#cost) for the full breakdown.

## Deploying your own policy

The infrastructure does not change when the policy does — point the variable at your file:

```bash
cd infra/4-hybrid/terraform
terraform apply -var policy_document=../../../my-policy.json
```

Your policy must declare `edge-locations` matching `var.aws_regions`, and its `attachment-policies` must match the tags this pattern applies. The validator checks both. A policy that gets either wrong deploys cleanly and moves no traffic.

## Cleanup

```bash
terraform destroy
```

## Next steps

- Share the core network across accounts: [`../../5-multi_account/`](../../5-multi\_account/)
- Build a routing policy that uses the prefix lists: [`../../../policy/6-routing_policies.md`](../../../policy/6-routing\_policies.md)
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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.58.0 |
| <a name="provider_aws.awshome"></a> [aws.awshome](#provider\_aws.awshome) | 6.58.0 |
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
| [aws_customer_gateway.cgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/customer_gateway) | resource |
| [aws_dx_gateway.dxgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dx_gateway) | resource |
| [aws_ec2_managed_prefix_list.ireland_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_managed_prefix_list) | resource |
| [aws_ec2_managed_prefix_list.nvirginia_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_managed_prefix_list) | resource |
| [aws_ec2_managed_prefix_list_entry.ireland_ipv4_entries](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_managed_prefix_list_entry) | resource |
| [aws_ec2_managed_prefix_list_entry.nvirginia_ipv4_entries](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_managed_prefix_list_entry) | resource |
| [aws_networkmanager_connect_attachment.connect_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_connect_attachment) | resource |
| [aws_networkmanager_connect_peer.connect_peer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_connect_peer) | resource |
| [aws_networkmanager_dx_gateway_attachment.dxgw_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_dx_gateway_attachment) | resource |
| [aws_networkmanager_prefix_list_association.ireland](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_prefix_list_association) | resource |
| [aws_networkmanager_prefix_list_association.nvirginia](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_prefix_list_association) | resource |
| [aws_networkmanager_site_to_site_vpn_attachment.vpn_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_site_to_site_vpn_attachment) | resource |
| [aws_vpn_connection.vpn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection) | resource |
| [awscc_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_core_network) | resource |
| [awscc_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_global_network) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_regions"></a> [aws\_regions](#input\_aws\_regions) | AWS Regions to create the environment. nvirginia and ireland must match the edge-locations in the policy document. | `map(string)` | <pre>{<br/>  "home": "us-west-2",<br/>  "ireland": "eu-west-1",<br/>  "nvirginia": "us-east-1"<br/>}</pre> | no |
| <a name="input_connect"></a> [connect](#input\_connect) | Connect (SD-WAN) configuration. null to skip. | <pre>object({<br/>    transport_vpc = string<br/>    region        = string<br/>    protocol      = string<br/>    peer_address  = optional(string)<br/>    peer_asn      = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_create_prefix_lists"></a> [create\_prefix\_lists](#input\_create\_prefix\_lists) | Create managed prefix lists in the home Region and associate them with the core network. | `bool` | `true` | no |
| <a name="input_direct_connect_gateway"></a> [direct\_connect\_gateway](#input\_direct\_connect\_gateway) | Direct Connect gateway configuration. null to skip. | <pre>object({<br/>    amazon_side_asn = number<br/>  })</pre> | `null` | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project identifier, used as a suffix when naming resources. | `string` | `"hybrid"` | no |
| <a name="input_ireland_spoke_vpcs"></a> [ireland\_spoke\_vpcs](#input\_ireland\_spoke\_vpcs) | Information about the spoke VPCs to create in eu-west-1. | <pre>map(object({<br/>    segment                 = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    cnetwork_subnet_netmask = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "dev": {<br/>    "cidr_block": "10.0.1.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "development",<br/>    "workload_subnet_netmask": 28<br/>  },<br/>  "prod": {<br/>    "cidr_block": "10.0.0.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "production",<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_nvirginia_spoke_vpcs"></a> [nvirginia\_spoke\_vpcs](#input\_nvirginia\_spoke\_vpcs) | Information about the spoke VPCs to create in us-east-1. | <pre>map(object({<br/>    segment                 = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    cnetwork_subnet_netmask = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "dev": {<br/>    "cidr_block": "10.10.1.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "development",<br/>    "workload_subnet_netmask": 28<br/>  },<br/>  "prod": {<br/>    "cidr_block": "10.10.0.0/24",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "production",<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_policy_document"></a> [policy\_document](#input\_policy\_document) | Path to the Cloud WAN network policy JSON document to deploy. | `string` | `"../baseline.json"` | no |
| <a name="input_site_to_site_vpn"></a> [site\_to\_site\_vpn](#input\_site\_to\_site\_vpn) | Site-to-Site VPN configuration. null to skip. | <pre>object({<br/>    customer_gateway_ip  = string<br/>    customer_gateway_asn = number<br/>    region               = string<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. |
| <a name="output_hybrid_attachments"></a> [hybrid\_attachments](#output\_hybrid\_attachments) | Hybrid attachments created. A null entry is a sub-type that was not enabled. |
| <a name="output_policy_document"></a> [policy\_document](#output\_policy\_document) | Path to the Cloud WAN network policy document deployed. |
| <a name="output_prefix_list_aliases"></a> [prefix\_list\_aliases](#output\_prefix\_list\_aliases) | Prefix list aliases a route-summarization policy can match with `prefix-in-prefix-list`. |
| <a name="output_spoke_vpcs"></a> [spoke\_vpcs](#output\_spoke\_vpcs) | Spoke VPCs created, by Region. |
<!-- END_TF_DOCS -->