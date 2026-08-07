# Infrastructure as Code resources

This section covers the resources you need to deploy an AWS Cloud WAN network (both in Terraform and CloudFormation). The good news: to build your global cloud network with Cloud WAN, you only need two resources: [Global network & Core network](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-visualize-networks.html). The network policy is a **property of the core network**, not a resource of its own. This means that, the rest of related resources are **attachment**, connecting VPCs, AWS Transit gateways or external networks (via AWS Direct Connect, AWS Site-to-Site VPN, or Connect attachments for SD-WAN networks) to the core network.

That's why in this section we will provide blueprints for you to understand how the different attachments are created and connect to the core network, and how Cloud WAN works in multi-Account environments. Pattern are organised by **which attachments they create**, and each one ships a `baseline.json`: a working policy that makes the pattern forward traffic the moment it deploys, without you writing anything. Swap in a policy of your own when you are ready — [`../policy/`](../policy/) is the place for you to dive deep on the policy document (alongside building the one for your use case).

## Prerequisites

- An **AWS account** with permissions for Network Manager, EC2 (VPCs, subnets, instances, endpoints), and IAM.
   * The inspection pattern needs Network Firewall.
   * The transit_gateway pattern needs Transit Gateway.
   * The multi_account pattern needs AWS RAM.
- The **AWS CLI**, configured with credentials.
- **Terraform**, or **`make`** for the CloudFormation path. The minimum Terraform version is in each pattern's generated `terraform/README.md`, under *Requirements*.

Every pattern creates real, billable resources. Use a non-production account, check the **Cost** section of the pattern you pick, and run the cleanup steps when you are finished.

## Patterns covered

| Pattern | Attachment types created | What covers |
|---------|--------------------------|----------------------------|
| [`1-basic`](./1-basic/) | `vpc` | Segmentation, segment sharing, route filtering between VPCs |
| [`2-inspection`](./2-inspection/) | `vpc` — spokes and inspection | Service insertion: egress or east-west inspection |
| [`3-transit_gateway`](./3-transit_gateway/) | `transit-gateway-route-table` | Transit Gateway coexistence |
| [`4-hybrid`](./4-hybrid/) | `vpc`, `site-to-site-vpn`, `direct-connect-gateway` | On-premises integration |
| [`5-multi_account`](./5-multi_account/) | none — the spoke accounts create them | Cross-account attachment governance |

## Pattern conventions

### Two Regions

Every pattern deploys **`us-east-1` and `eu-west-1`**. To add another: add a `provider` alias in `terraform/providers.tf`, add a VPC module block in `terraform/main.tf`, and add the Region to `edge-locations` in your policy. Cloud WAN needs no other change, because segments are global — a new Core Network Edge picks up the existing segments and attachment policies.

[`4-hybrid`](./4-hybrid/) also configures **`us-west-2`**, because managed prefix lists associated with a core network must be created in Cloud WAN's home Region. It hosts no Core Network Edge and does not appear in the policy; in `var.aws_regions` it is keyed `home`, which is how [`../tools/validate_policy.py`](../tools/) excludes it from the edge-location check.

### Attachment tags

Every pattern applies the same tags, so a policy written against one pattern binds against any other that has the attachment types it needs.

| Tag | Applied to | Effect |
|-----|------------|--------|
| `domain = <segment name>` | VPC attachments, Transit Gateway route-table attachments | Associates the attachment to the segment named by the tag **value** |
| `inspection = true` | Inspection VPC attachments | Adds the attachment to the inspection network function group |

Hybrid attachments — Site-to-Site VPN, Connect, Direct Connect gateway — carry **no tag**. They are matched on `attachment-type`, which [`4-hybrid`](./4-hybrid/) is built around. [`../policy/3-attachment_policies.md`](../policy/3-attachment_policies.md) covers both binding methods.

To use a different scheme, change it in the pattern's Terraform, its CloudFormation, and its `baseline.json`. Change all three or attachments will deploy and never associate.

### Terraform and CloudFormation

Every pattern ships both. They deploy the same infrastructure from the same policy document, with these operational differences:

| | Terraform | CloudFormation |
|---|---|---|
| How the policy gets in | `file(var.policy_document)`, defaulting to the pattern's `baseline.json` | Generated into `core_network.yaml` by [`../tools/sync_cfn_policy.py`](../tools/) |
| Using a different policy | `-var policy_document=...` | Replace `baseline.json`, regenerate, update the stack |
| Deploy steps | One `apply` | Separate core-network and workload stacks, ordered by `make` |
| Not covered | — | `4-hybrid`'s hybrid attachments and prefix lists; `2-inspection` needs three phases |

The policy is generated into the CloudFormation template because a stack parameter caps at 4096 characters and a real policy exceeds that. CI fails if a generated template no longer matches its `baseline.json`.

`2-inspection` needs three CloudFormation phases because a service-insertion action cannot reference a network function group that has no attachments yet. `4-hybrid`'s hybrid attachments and prefix lists are Terraform-only; its policy still associates them by attachment type, so one created by hand against a CloudFormation deployment lands in the `hybrid` segment automatically.

## Deploying a policy of your own

The infrastructure does not change when the policy does. Build a policy in [`../policy/`](../policy/) — by hand from its snippets, or with an agent following [`../policy/policy_generator.md`](../policy/policy_generator.md) — then point the pattern at it:

```bash
cd infra/2-inspection/terraform
terraform apply -var policy_document=../../../my-policy.json
```

Whatever you write has to satisfy two things, or it will deploy cleanly and move no traffic: its `attachment-policies` must match the tags the pattern applies, and its `edge-locations` must match the Regions the pattern deploys into.

CloudFormation needs the policy inline in the template rather than in a separate file, so its steps differ — see the pattern's `cloudformation/README.md`. Tell the policy generator which tool you are using and it hands back the policy in the right form for either.

Replacing a core network's policy is an in-place operation — you do not tear down attachments to change segments or routing.
