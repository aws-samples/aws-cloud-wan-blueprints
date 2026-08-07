<!-- BEGIN_TF_DOCS -->
# Infra pattern 5 — Multi-account (Terraform)

A global network, a core network, and an AWS RAM share of that core network with one or more spoke accounts.

See [the pattern README](../README.md) for what this builds, what its baseline policy demonstrates, the cross-account limitations that matter, and how to verify it. See [`infra/README.md`](../../README.md) for cost, the tagging contract, and how to bring your own policy.

## Prerequisites

- An AWS account with permissions for Network Manager, AWS RAM, and IAM. No EC2 permissions are needed — this pattern creates no workloads.
- The AWS CLI, configured with credentials.
- Terraform. The minimum version is in the **Requirements** table below, which is generated from the code.

## Deploy

`share_with_principals` has no default, so pass it on the command line:

```bash
cd infra/5-multi_account/terraform
terraform init
terraform apply -var 'share_with_principals=["111122223333"]'
```

A principal can be an AWS account ID, an organizational unit ARN, or an organization ARN. Prefer account IDs or an OU ARN — see [the limitations](../README.md#share-scope-prefer-accounts-and-ous-over-the-whole-organization).

If the spoke account is outside your AWS Organization:

```bash
terraform apply -var 'share_with_principals=["111122223333"]' -var allow_external_principals=true
```

## Deploying your own policy

The infrastructure does not change when the policy does — point the variable at your file:

```bash
cd infra/5-multi_account/terraform
terraform apply -var policy_document=../../../my-policy.json
```

Your policy must declare `edge-locations` matching `var.aws_regions`. This pattern creates no attachments of its own, so the tags to match are the ones the **spoke accounts** apply to theirs — which is exactly the cross-account exposure described in [the pattern README](../README.md#cross-account-limitations).

## Cleanup

```bash
terraform destroy
```

## Next steps

- Deploy workloads in the spoke account using another pattern's workload code: [`../../1-basic/`](../../1-basic/)
- Harden the attachment policies against cross-account tagging: [`../README.md#cross-account-limitations`](../README.md#cross-account-limitations)
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
| <a name="provider_aws.awsnvirginia"></a> [aws.awsnvirginia](#provider\_aws.awsnvirginia) | 6.58.0 |
| <a name="provider_awscc.awsccnvirginia"></a> [awscc.awsccnvirginia](#provider\_awscc.awsccnvirginia) | 1.95.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ram_principal_association.principals](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.core_network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.core_network_share](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |
| [awscc_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_core_network) | resource |
| [awscc_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/networkmanager_global_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_external_principals"></a> [allow\_external\_principals](#input\_allow\_external\_principals) | Allow sharing with principals outside your AWS Organization. | `bool` | `false` | no |
| <a name="input_aws_regions"></a> [aws\_regions](#input\_aws\_regions) | AWS Regions the core network spans. Must match the edge-locations in the policy document. | `map(string)` | <pre>{<br/>  "ireland": "eu-west-1",<br/>  "nvirginia": "us-east-1"<br/>}</pre> | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project identifier, used as a suffix when naming resources. | `string` | `"multi-account"` | no |
| <a name="input_policy_document"></a> [policy\_document](#input\_policy\_document) | Path to the Cloud WAN network policy JSON document to deploy. | `string` | `"../baseline.json"` | no |
| <a name="input_share_with_principals"></a> [share\_with\_principals](#input\_share\_with\_principals) | Principals to share the core network with: account IDs, or Organization / OU ARNs. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. Pass these to the spoke accounts so they can create attachments. |
| <a name="output_policy_document"></a> [policy\_document](#output\_policy\_document) | Path to the Cloud WAN network policy document deployed. |
| <a name="output_resource_share_arn"></a> [resource\_share\_arn](#output\_resource\_share\_arn) | AWS RAM resource share ARN. A spoke account outside your Organization needs this to accept the invitation. |
| <a name="output_shared_with"></a> [shared\_with](#output\_shared\_with) | Principals the core network is shared with. |
<!-- END_TF_DOCS -->