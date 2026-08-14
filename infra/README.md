# Infrastructure as Code resources

This section covers the resources you need to deploy an AWS Cloud WAN network. You only need two: a [global network and a core network](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-visualize-networks.html). The network policy is a **property of the core network**, not a resource of its own, and everything else you deploy is an **attachment**: VPCs, AWS Transit Gateways, Direct Connect gateways, Site-to-Site VPNs, or Connect attachments.

So the patterns here show how those attachments are created and connect to the core network, and how Cloud WAN works in multi-account environments. Each one ships a `baseline.json`: a working policy that makes the pattern forward traffic the moment it deploys, without you writing anything. Swap in [a policy of your own](#deploying-a-policy-of-your-own) when you are ready.

[AWS CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html) and [Terraform](https://developer.hashicorp.com/terraform) are the two IaC tools covered, and **every pattern ships both**. How you deploy each pattern in each IaC tool is documented per tool, per pattern: each `terraform/README.md` and `cloudformation/README.md` covers its own prerequisites, deploy and cleanup commands.

| Pattern | Attachment types created | What it covers |
|---------|--------------------------|----------------|
| [`1-basic`](./1-basic/) | `vpc` | Segmentation, tag-based association, and non-transitive segment sharing |
| [`2-inspection`](./2-inspection/) | `vpc` — spokes and inspection | Service insertion: egress and east-west inspection |
| [`3-transit_gateway`](./3-transit_gateway/) | `transit-gateway-route-table` | Transit Gateway coexistence |
| [`4-hybrid`](./4-hybrid/) | `vpc`, `site-to-site-vpn`, `direct-connect-gateway` | On-premises integration, and association by attachment type |
| [`5-multi_account`](./5-multi_account/) | none — spoke accounts create their own | Cross-account attachment governance |
| [`6-prefix_list_association`](./6-prefix_list_association/) | none | Associating a managed prefix list so a routing policy can match on its alias |

## Your architecture may not match a pattern exactly

That is expected, and it is not a gap in these blueprints. AWS Cloud WAN designs vary along more axes than a directory tree can hold, so the number of complete end-to-end architectures is effectively unbounded. Shipping one directory per architecture will be hard to maintain and for consumers difficult to find their specific use case. What *is* bounded is the set of **building blocks**: the attachment types, and how each one is created and connected to a core network. That is all a pattern is. Between them these six cover every attachment type AWS Cloud WAN supports, how multi-Account works with a core network, and how you can associate prefix lists to the core network. So pick the pattern whose attachment types match what you need to connect, and treat it as the substrate rather than the answer.

Then put your effort into the **policy**, because that is what separates your design from anyone else's. Two networks with byte-identical infrastructure behave completely differently depending on their segments, sharing, service insertion, and routing policies. Head to [`policy/`](../policy/) for that, and see [Deploying a policy of your own](#deploying-a-policy-of-your-own) below for how to point a pattern at what you write.

When you do need to change the infrastructure, the change is usually small and local:

- **Another Region, or different ones.** See [Regions](#regions).
- **Different tags, or binding by type instead.** See [How attachments are associated](#how-attachments-are-associated).
- **A piece from a second pattern.** Nothing stops you combining them, and the patterns are deliberately shaped so you can.

## Prerequisites

- An **AWS account** with permissions for Network Manager, EC2 (VPCs, subnets, instances, endpoints), and IAM.
  - `2-inspection` also needs Network Firewall.
  - `3-transit_gateway` also needs Transit Gateway.
  - `4-hybrid` also needs Site-to-Site VPN and Direct Connect. Each is independently optional, and the Direct Connect gateway attachment needs a real circuit to carry traffic.
  - `5-multi_account` also needs AWS RAM, and a second AWS account to accept the share.
  - `6-prefix_list_association` needs EC2 managed prefix lists, and no VPC or instance permissions at all.
- The **AWS CLI**, configured with credentials.
- **Terraform**, if you deploy with Terraform. The minimum version is in each pattern's `terraform/README.md`, under *Requirements*.
- **`make`**, if you deploy with CloudFormation.

> Every pattern creates real, billable resources. Use a non-production account, check the **Cost** section of the pattern you pick, and run the cleanup steps when you are finished.

## Deploying a policy of your own

AWS Cloud WAN builds the network from the policy document, so the way to get value out of these infrastructure patterns is to deploy one and point it at a policy closer to your own use case.

If you want to understand the building blocks, the `baseline.json` document we provide in each pattern is enough. However, if you want to get the full value of these blueprints, start in the [`policy/`](../policy/) section: it is organised around what an AWS Cloud WAN policy can express, with snippets to assemble. The [generator capability in `SKILLS.md`](../SKILLS.md#building-a-policy) helps you turn your requirements into a finished document.

If you select to build your own policy, two things about a pattern may then need to change to match it — the **Regions** you deploy into, and the **way attachments are associated**. Keep both as they come and there is nothing to change.

> Swapping the policy on a running core network is an in-place operation. You do not tear down attachments to change segments, routing, or inspection insertion.

### Regions

Every `baseline.json` declares **`us-east-1` and `eu-west-1`** as its `edge-locations`, so every core network gets the same two Core Network Edges. Segments are global and pick them up automatically, unless a segment scopes itself with its own `edge-locations`.

Where the resources actually live differs, because two patterns create no attachments:

| Pattern | Resources in | Why |
|---------|--------------|-----|
| `1-basic`, `2-inspection`, `3-transit_gateway`, `4-hybrid` | `us-east-1`, `eu-west-1` | Matches the edge locations |
| `5-multi_account` | `us-east-1` and `us-west-2` | A global resource can only be shared through AWS RAM from `us-east-1` |
| `6-prefix_list_association` | `us-west-2` | An associated prefix list has to live in AWS Cloud WAN's home Region |

**To add a Region, or use different ones**, put it in the policy's `edge-locations` and then follow the infrastructure that attaches to the core network. For `5-multi_account` and `6-prefix_list_association` the policy is the only change. For the other four:

| Tool | File | Add |
|------|------|-----|
| Terraform | `variables.tf` | The Region in `aws_regions`, plus the pattern's per-Region variables (table below) |
| Terraform | `providers.tf` | An `aws` provider block with a new `alias`. Provider blocks take no `for_each`, so every Region costs a literal block. The `awscc` alias is **not** duplicated — it is only the API endpoint for the global and core network, not a constraint on where edges are created |
| Terraform | `main.tf` | The VPC and compute module blocks, each pinned to the new alias |
| CloudFormation | `workloads.yaml` | An entry keyed by Region name in each `Mappings` block (table below). The resources need no edit, because they read values with `!FindInMap [<map>, !Ref 'AWS::Region', ...]` |
| CloudFormation | `Makefile` | A Region variable, a stack-name variable, and a `deploy`/`undeploy` line. The same `workloads.yaml` deploys once per Region |

What is keyed per Region differs per pattern:

| Pattern | Terraform variables | CloudFormation `Mappings` |
|---------|--------------------|---------------------------|
| `1-basic` | `<region>_spoke_vpcs` | `ProdVpcCIDR`, `DevVpcCIDR`, `SharedVpcCIDR` |
| `2-inspection` | `<region>_spoke_vpcs`, `<region>_inspection_vpc` | `ProdVpcCIDR`, `DevVpcCIDR`, `InspectionVpcCIDR` |
| `3-transit_gateway` | `<region>_spoke_vpcs`, `transit_gateway_asns` | `ProdVpcCIDR`, `DevVpcCIDR`, `TransitGatewayASN` |
| `4-hybrid` | `<region>_spoke_vpc` — one VPC per Region | `SpokeVpcCIDR` |

To use different Regions rather than more of them, rename the keys instead of adding to them. A new Transit Gateway ASN has to stay outside the policy's `asn-ranges`.

### How attachments are associated

An attachment does not choose its own segment — the policy's `attachment-policies` do, matching on the attachment's tags, type, account, or Region. What the infrastructure sets and what the policy matches on are two halves of one contract, so they have to agree.

> Deploy a pattern with its `baseline.json` and attachments associate correctly, with nothing to check. The same holds if you write your own policy and leave its `attachment-policies` as they come.

Where a pattern binds by tag it always works the same way: the rule matches `tag-exists: domain` and associates to the segment **named by the tag's value**, so one rule serves every segment.

| Pattern | Tags applied to attachments | Bound by |
|---------|----------------------------|----------|
| `1-basic` | `domain = <segment>` | Tag value |
| `2-inspection` | `domain = <segment>` on the spokes, `inspection = true` on the inspection VPC | Tag value; `inspection` adds to the `inspectionVpcs` network function group instead of a segment |
| `3-transit_gateway` | `domain = <segment>`, on the Transit Gateway route table attachments | Tag value |
| `4-hybrid` | **none** | `attachment-type`, with the segment as a constant: hybrid types to `hybrid`, `vpc` to `vpcs` |
| `5-multi_account` | `domain = <segment>`, applied by the **attachment owner** | Tag value |
| `6-prefix_list_association` | `domain = <segment>`, but no attachments are created | Tag value |

Both methods are shipped deliberately, and the choice generalises. **Tag when the destination is a choice:** a VPC could reasonably belong to any segment, so something has to say which. **Match the type when the type is the intent:** a Direct Connect gateway attachment is hybrid by definition, so a tag would only add something to get wrong. `4-hybrid` binds everything by type to stay consistent within the pattern.

Changing the scheme? [`3-attachment_policies.md`](../policy/3-attachment_policies.md) covers how association logic maps onto tags. If the tags and the policy disagree, attachments still deploy and reach `AVAILABLE` — they simply associate to nothing, and no routes propagate.
