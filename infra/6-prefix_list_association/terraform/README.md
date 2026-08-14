<!-- BEGIN_TF_DOCS -->
# Infrastructure-as-Code Patterns — AWS Cloud WAN prefix list association (Terraform)

In this pattern, we want to show how a managed prefix list is associated with a core network so a routing policy can match on its alias, and how to deploy that without hitting the circular dependency between the two.

See [the pattern README](../README.md) for what this builds, why two policy documents are needed, what each one configures, and how to verify it.

## Prerequisites

- An AWS account with permissions for Network Manager, EC2 (managed prefix lists), and IAM. No VPC or EC2 instance permissions are needed — this pattern creates no workloads.
- The AWS CLI, configured with credentials.
- Terraform. The minimum version is in the **Requirements** table below.

## Deploy

```bash
cd infra/6-prefix_list_association/terraform
terraform init
terraform plan
terraform apply
```

One `apply` is enough. Terraform orders the required steps for you: the core network is created with [`../baseline.json`](../baseline.json), then the prefix list, then the association, and only then is [`../baseline_prefix_list.json`](../baseline\_prefix\_list.json) attached.

> **Why two policy documents?** A routing policy matches a prefix list by **alias**, and the alias only exists once the prefix list is associated with the core network. The association needs a core network ID, so the core network must already exist — and AWS Cloud WAN rejects a policy naming an alias it cannot resolve. `var.policy_document` is therefore the policy the core network is created with, and `var.prefix_list_policy_document` is attached afterwards. The `depends_on` in `main.tf` is what enforces the order.

> **Using a policy of your own?** No Terraform changes needed — `main.tf` reads whatever files `var.policy_document` and `var.prefix_list_policy_document` point at. Drop your documents in the pattern folder next to the baselines, then `terraform apply -var policy_document=../my-base.json -var prefix_list_policy_document=../my-policy.json`. Paths are relative to this directory, which is why the defaults are `../baseline.json` and `../baseline_prefix_list.json`. If your policy references a different alias, set `var.prefix_list_alias` to match.

## Cleanup

Two steps, in this order:

```bash
terraform apply -var prefix_list_policy_document=../baseline.json
terraform destroy
```

The first command re-attaches the policy **without** the alias. The second then destroys everything.

> **Why `destroy` alone is not enough.** Destroying `aws_networkmanager_core_network_policy_attachment` does not revert the live policy. So a plain `terraform destroy` leaves [`../baseline_prefix_list.json`](../baseline\_prefix\_list.json) live, that policy still matches on the alias, and AWS Cloud WAN refuses to delete the association the alias belongs to. Pointing `var.prefix_list_policy_document` at [`../baseline.json`](../baseline.json) first breaks the reference.

If you deployed with policy documents of your own, revert to whichever of them does **not** reference the alias:

```bash
terraform apply -var policy_document=../my-base.json -var prefix_list_policy_document=../my-base.json
terraform destroy
```

---

Everything below is generated from the Terraform source by `terraform-docs`. Do not edit `README.md` directly — edit [`.header.md`](./.header.md) and regenerate.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.34.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws.awsoregon"></a> [aws.awsoregon](#provider\_aws.awsoregon) | 6.58.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ec2_managed_prefix_list.prefix_list](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_managed_prefix_list) | resource |
| [aws_ec2_managed_prefix_list_entry.prefix_list_entry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_managed_prefix_list_entry) | resource |
| [aws_networkmanager_core_network.core_network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_core_network) | resource |
| [aws_networkmanager_core_network_policy_attachment.prefix_list_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_core_network_policy_attachment) | resource |
| [aws_networkmanager_global_network.global_network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_global_network) | resource |
| [aws_networkmanager_prefix_list_association.prefix_list_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkmanager_prefix_list_association) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_regions"></a> [aws\_regions](#input\_aws\_regions) | Region this deployment is managed from: oregon is Cloud WAN's home Region. | `map(string)` | <pre>{<br/>  "oregon": "us-west-2"<br/>}</pre> | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Project identifier, used as a suffix when naming resources. | `string` | `"prefix-list"` | no |
| <a name="input_policy_document"></a> [policy\_document](#input\_policy\_document) | Path to the policy the core network is created with. Must not reference the prefix list alias. | `string` | `"../baseline.json"` | no |
| <a name="input_prefix_list_alias"></a> [prefix\_list\_alias](#input\_prefix\_list\_alias) | Alias the prefix list is associated under. Must match the prefix-in-prefix-list value in the policy document. | `string` | `"routesfiltered"` | no |
| <a name="input_prefix_list_cidrs"></a> [prefix\_list\_cidrs](#input\_prefix\_list\_cidrs) | CIDR blocks the prefix list contains. These are the prefixes a routing policy matches on by alias. | `list(string)` | <pre>[<br/>  "10.100.0.0/16",<br/>  "192.168.0.0/16"<br/>]</pre> | no |
| <a name="input_prefix_list_policy_document"></a> [prefix\_list\_policy\_document](#input\_prefix\_list\_policy\_document) | Path to the policy attached after the prefix list association exists. This one references the prefix list alias. | `string` | `"../baseline_prefix_list.json"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_wan"></a> [cloud\_wan](#output\_cloud\_wan) | AWS Cloud WAN resources. |
| <a name="output_prefix_list"></a> [prefix\_list](#output\_prefix\_list) | The managed prefix list. |
<!-- END_TF_DOCS -->