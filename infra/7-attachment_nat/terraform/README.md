<!-- BEGIN_TF_DOCS -->
# Infrastructure-as-Code Patterns — 1:1 NAT on AWS Cloud WAN attachments (Terraform)

In this pattern, we want to show how 1:1 NAT on Cloud WAN attachments connects networks whose CIDRs overlap.

See [the pattern README](../README.md) for what this builds, the NAT rules and tags it applies, what its baseline policy configures, and how to verify it.

## Prerequisites

- An AWS account with permissions for Network Manager, EC2 (VPCs, subnets, instances, endpoints, plus customer gateways and VPN connections for the optional VPN), and IAM.
- The AWS CLI, configured with credentials.
- Terraform. The minimum version is in the **Requirements** table below.

## Deploy

```bash
cd infra/7-attachment_nat/terraform
terraform init
terraform plan
terraform apply
```

That deploys the pattern with its working baseline policy, [`../baseline.json`](../baseline.json): the core network and the three VPCs. A VPC whose entry in `nvirginia_vpcs` or `ireland_vpcs` sets `nat_cidr` is attached by the `*_nat` attachment resource, with a NAT rule translating its `cidr_block` to `nat_cidr`; a VPC without `nat_cidr` gets a plain attachment.

The VPN is off by default, because it needs values only you can supply. The customer gateway ASN must not overlap the core network's `asn-ranges`, which the baseline sets to `64520-64525`:

```bash
terraform apply -var 'site_to_site_vpn={customer_gateway_ip="203.0.113.10",customer_gateway_asn=65010}'
```

`onprem_cidr` (default `10.10.0.0/16`) and `nat_cidr` (default `100.66.0.0/16`) are optional fields of the same object. To keep the VPN on across runs, put the object in a local `terraform.tfvars` instead, which Terraform loads automatically and the repository's `.gitignore` keeps out of commits:

```hcl
site_to_site_vpn = {
  customer_gateway_ip  = "203.0.113.10"
  customer_gateway_asn = 65010
}
```

The VPN tunnels stay down until a real on-premises device answers at `customer_gateway_ip`; see [Hybrid attachments](../README.md#hybrid-attachments) for what you can check without one.

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
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.110.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ireland_compute"></a> [ireland\_compute](#module\_ireland\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_ireland_vpcs"></a> [ireland\_vpcs](#module\_ireland\_vpcs) | aws-ia/vpc/aws | = 4.9.0 |
| <a name="module_nvirginia_compute"></a> [nvirginia\_compute](#module\_nvirginia\_compute) | ../../tf_modules/compute | n/a |
| <a name="module_nvirginia_vpcs"></a> [nvirginia\_vpcs](#module\_nvirginia\_vpcs) | aws-ia/vpc/aws | = 4.9.0 |

## Resources

| Name | Type |
|------|------|
| [aws_customer_gateway.cgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/customer_gateway) | resource |
| [aws_route.ireland_cwan_route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.nvirginia_cwan_route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_vpn_connection.vpn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection) | resource |
| [awscc_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_core_network) | resource |
| [awscc_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_global_network) | resource |
| [awscc_networkmanager_site_to_site_vpn_attachment.vpn_attachment](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_site_to_site_vpn_attachment) | resource |
| [awscc_networkmanager_vpc_attachment.ireland_nat](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_vpc_attachment) | resource |
| [awscc_networkmanager_vpc_attachment.nvirginia](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_vpc_attachment) | resource |
| [awscc_networkmanager_vpc_attachment.nvirginia_nat](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_vpc_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_regions"></a> [aws\_regions](#input\_aws\_regions) | AWS Regions to create the environment. Must match the edge-locations in the policy document. | `map(string)` | <pre>{<br/>  "ireland": "eu-west-1",<br/>  "nvirginia": "us-east-1"<br/>}</pre> | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project identifier, used as a suffix when naming resources. | `string` | `"overlap"` | no |
| <a name="input_ireland_vpcs"></a> [ireland\_vpcs](#input\_ireland\_vpcs) | Information about the VPCs to create in eu-west-1. | <pre>map(object({<br/>    segment                 = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    nat_cidr                = optional(string)<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    cnetwork_subnet_netmask = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "acquired-b": {<br/>    "cidr_block": "10.10.0.0/16",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "nat_cidr": "100.65.0.0/16",<br/>    "number_azs": 2,<br/>    "segment": "corporate",<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_nvirginia_vpcs"></a> [nvirginia\_vpcs](#input\_nvirginia\_vpcs) | Information about the VPCs to create in us-east-1. | <pre>map(object({<br/>    segment                 = string<br/>    number_azs              = number<br/>    cidr_block              = string<br/>    nat_cidr                = optional(string)<br/>    workload_subnet_netmask = number<br/>    endpoint_subnet_netmask = number<br/>    cnetwork_subnet_netmask = number<br/>    instance_type           = string<br/>  }))</pre> | <pre>{<br/>  "acquired-a": {<br/>    "cidr_block": "10.10.0.0/16",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "nat_cidr": "100.64.0.0/16",<br/>    "number_azs": 2,<br/>    "segment": "corporate",<br/>    "workload_subnet_netmask": 28<br/>  },<br/>  "shared": {<br/>    "cidr_block": "10.0.0.0/16",<br/>    "cnetwork_subnet_netmask": 28,<br/>    "endpoint_subnet_netmask": 28,<br/>    "instance_type": "t2.micro",<br/>    "number_azs": 2,<br/>    "segment": "shared",<br/>    "workload_subnet_netmask": 28<br/>  }<br/>}</pre> | no |
| <a name="input_policy_document"></a> [policy\_document](#input\_policy\_document) | Path to the Cloud WAN network policy JSON document to deploy. | `string` | `"../baseline.json"` | no |
| <a name="input_site_to_site_vpn"></a> [site\_to\_site\_vpn](#input\_site\_to\_site\_vpn) | Site-to-Site VPN configuration, created in us-east-1. The customer gateway ASN must not overlap the asn-ranges in the policy document. onprem\_cidr is translated to nat\_cidr. null to skip. | <pre>object({<br/>    customer_gateway_ip  = string<br/>    customer_gateway_asn = number<br/>    onprem_cidr          = optional(string, "10.10.0.0/16")<br/>    nat_cidr             = optional(string, "100.66.0.0/16")<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. |
| <a name="output_site_to_site_vpn_attachment"></a> [site\_to\_site\_vpn\_attachment](#output\_site\_to\_site\_vpn\_attachment) | Site-to-Site VPN attachment ID. null when the VPN is not enabled. |
| <a name="output_vpcs"></a> [vpcs](#output\_vpcs) | VPCs created, by Region: the VPC ID, its real CIDR, the NAT CIDR other networks reach it at (null without NAT), and its VPC attachment ID. |
<!-- END_TF_DOCS -->