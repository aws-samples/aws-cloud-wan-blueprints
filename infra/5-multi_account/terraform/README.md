<!-- BEGIN_TF_DOCS -->
# Infrastructure-as-Code Patterns — AWS Cloud WAN shared across accounts (Terraform)

In this pattern, we want to show how a core network is shared with other AWS accounts using AWS Resource Access Manager.

![Multi-account architecture](../../../images/5-multi\_account.png)

See [the pattern README](../README.md) for what this builds, what its baseline policy configures, and how to verify the deployment.

## Prerequisites

- An AWS account with permissions for Network Manager, AWS RAM, and IAM. No EC2 permissions are needed — this pattern creates no workloads.
- **A second AWS account to share with** — the spoke account — or an organizational unit or organization containing one. The deployment succeeds without it, because RAM will happily share with a principal you do not control — but nothing can be verified until the spoke account accepts the share and creates an attachment.
- The AWS CLI, configured with credentials.
- Terraform. The minimum version is in the **Requirements** table below.

## Deploy

`var.share_with` has no default, because only you know who to share with. Pass one of the three forms:

```bash
cd infra/5-multi_account/terraform
terraform init
terraform plan  -var 'share_with={type="account",value="111122223333"}'
terraform apply -var 'share_with={type="account",value="111122223333"}'
```

```bash
# An organizational unit
terraform apply -var 'share_with={type="organizational_unit",value="arn:aws:organizations::111122223333:ou/o-abc123def4/ou-ab12-cdef3456"}'

# A whole organization
terraform apply -var 'share_with={type="organization",value="arn:aws:organizations::111122223333:organization/o-abc123def4"}'
```

That deploys the pattern with its working baseline policy, [`../baseline.json`](../baseline.json).

> **Sharing with an organizational unit or an organization needs one-off setup.** Run `aws ram enable-sharing-with-aws-organization` once, from the management account. Until then RAM accepts individual account IDs only. Those shares are also auto-accepted, whereas sharing with an account ID sends an invitation the spoke account has to accept.

> **Using a policy of your own?** No Terraform changes needed — `main.tf` reads whatever file `var.policy_document` points at. Drop your document in the pattern folder next to the baseline, then `terraform apply -var policy_document=../my-policy.json`. Paths are relative to this directory, which is why the default is `../baseline.json`; change that default in `variables.tf` to stop passing `-var` every time.

## Cleanup

```bash
terraform destroy
```

A core network with attachments from a spoke account cannot be deleted, so every spoke account has to remove its attachments first.

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
| <a name="provider_aws.awsnvirginia"></a> [aws.awsnvirginia](#provider\_aws.awsnvirginia) | >= 6.34.0 |
| <a name="provider_awscc.awsccoregon"></a> [awscc.awsccoregon](#provider\_awscc.awsccoregon) | >= 1.67.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ram_principal_association.principal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.core_network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.core_network_share](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |
| [awscc_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_core_network) | resource |
| [awscc_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_global_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_share_with"></a> [share\_with](#input\_share\_with) | Who to share the core network with. Type is `account`, `organizational_unit` or `organization`; value is a 12-digit account ID or an AWS Organizations ARN. | <pre>object({<br/>    type  = string<br/>    value = string<br/>  })</pre> | n/a | yes |
| <a name="input_aws_regions"></a> [aws\_regions](#input\_aws\_regions) | Regions this deployment is managed from: oregon is Cloud WAN's home Region, nvirginia is where AWS RAM shares the core network from. Not edge locations. | `map(string)` | <pre>{<br/>  "nvirginia": "us-east-1",<br/>  "oregon": "us-west-2"<br/>}</pre> | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project identifier, used as a suffix when naming resources. | `string` | `"multi-account"` | no |
| <a name="input_policy_document"></a> [policy\_document](#input\_policy\_document) | Path to the Cloud WAN network policy JSON document to deploy. | `string` | `"../baseline.json"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. Pass these to the spoke accounts so they can create attachments. |
| <a name="output_resource_share_arn"></a> [resource\_share\_arn](#output\_resource\_share\_arn) | AWS RAM resource share ARN. A spoke account outside your Organization needs this to accept the invitation. |
<!-- END_TF_DOCS -->