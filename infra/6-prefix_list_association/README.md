# Infrastructure-as-Code Patterns — AWS Cloud WAN prefix list association

In this pattern, we want to show how a managed prefix list is associated with a core network so a routing policy can match on its alias, and how to deploy that without hitting the circular dependency between the two.

<!-- DIAGRAM PLACEHOLDER -->
> _Architecture diagram to be added._

## Implementations

| IaC | Directory |
|-----|-----------|
| Terraform | [`terraform/`](./terraform/) |
| CloudFormation | [`cloudformation/`](./cloudformation/) |

> New to the repository? Read [`../README.md`](../README.md) first.

## What gets deployed

| Component | Configuration |
|-----------|---------------|
| AWS Cloud WAN resources | Global network & core network, managed in `us-west-2` |
| Managed prefix list | One, in `us-west-2`, containing `10.100.0.0/16` and `192.168.0.0/16` |
| Prefix list association | Associates that prefix list with the core network under the alias `routesfiltered` |
| Policy documents | **Two.** One to create the core network with, one to attach afterwards |
| Workloads | **None.** This pattern is about the association, not about traffic |

**Attachment types created:** none. The core network's attachment policy will place a `vpc` attachment tagged `domain = vpcs` into the `vpcs` segment, so you can add one from another pattern if you want routes in the table — but nothing here creates an attachment.

The prefix list has to be created in `us-west-2`, Cloud WAN's home Region, regardless of where the edge locations are. The association is global once made, and applies to every core network edge. See [AWS Cloud WAN prefix list associations](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-prefix-lists.html).

## The circular dependency

This is the whole point of the pattern, and it is worth stating precisely.

A routing policy never names a prefix list by ID or ARN. It matches on an **alias**:

```json
{ "type": "prefix-in-prefix-list", "value": "routesfiltered" }
```

That alias is created by the association, not by the prefix list. So:

1. The **association** needs a core network ID — the core network must exist first.
2. The core network is created **with a policy**.
3. A policy naming an alias that does not resolve is **rejected** by Cloud WAN.

Put those together and a core network's *first* policy can never reference a prefix list alias. There is no ordering of a single step that satisfies all three.

The way out is two policy documents:

| Document | Applied | Contains |
|----------|---------|----------|
| [`baseline.json`](./baseline.json) | When the core network is created | Segments and attachment policies. No routing policy, no alias |
| [`baseline_prefix_list.json`](./baseline_prefix_list.json) | After the association exists | The same, plus a routing policy matching on `routesfiltered`, and the rule that binds it to attachments |

The two differ by exactly one section, which makes the diff easy to read and easy to keep honest — CI compares each one against its CloudFormation template.

Each tool expresses this differently:

| | How the order is enforced | To deploy | To tear down |
|---|---|---|---|
| Terraform | `depends_on` between the policy attachment and the association. `aws_networkmanager_core_network` takes a *base* policy; `aws_networkmanager_core_network_policy_attachment` applies the real one | One `terraform apply` | One `terraform apply` to revert the policy, then `terraform destroy` |
| CloudFormation | The prefix list and association live in their own stack, then the core network stack is updated with the second template | Three `make` targets | `make undeploy`, whose first step reverts the policy |

CloudFormation genuinely cannot do this in one template: it would need the core network before the association, and the association before the core network's policy. Terraform can, because the base policy and the final policy are two different resources.

### Teardown has the same dependency, in reverse

An association cannot be deleted while a live policy still matches on its alias, so the policy has to go back to the one without the alias first. **Neither tool does this for you.**

CloudFormation is explicit about it: `make undeploy` runs `revert-policy` before it deletes anything.

Terraform needs the same thing done by hand, and the reason is worth knowing. Destroying `aws_networkmanager_core_network_policy_attachment` does not revert the live policy — the provider documents that deleting the resource neither deletes the policy it applied nor rolls the core network back to its previous version. Terraform therefore destroys in the right order and it still fails: the attachment is dropped from state, `baseline_prefix_list.json` stays live, and Cloud WAN refuses to delete the association its alias belongs to. No `depends_on` or `lifecycle` block changes this, because the blocker is a live reference inside the service rather than an ordering problem in the graph.

Breaking the reference is one `apply` with the alias-free policy:

```bash
terraform apply -var prefix_list_policy_document=../baseline.json
terraform destroy
```

This is the same shape as the CloudFormation `revert-policy` step, expressed with the variable the pattern already has.

## What the baseline policies configure

| | |
|---|---|
| Segments | `vpcs`, not isolated, no acceptance required |
| Attachment policy | Rule 100 matches `attachment-type = vpc` **and** `tag-exists: domain`, then associates by the tag's value |
| Routing policy | **Only in `baseline_prefix_list.json`:** `filterSecondaryRoutes`, direction `inbound`, whose rule 100 matches `prefix-in-prefix-list: routesfiltered` and acts `drop` |
| Routing policy binding | **Only in `baseline_prefix_list.json`:** an `attachment-routing-policy-rules` entry that associates `filterSecondaryRoutes` with attachments carrying the routing policy label `vpcAttachment`, at both edge locations |

This is a route-filtering use of a prefix list: the aliased prefixes are dropped as they are learned **into** the core network, so the segment route table never gets them. Filtering on a prefix list rather than on literal CIDR blocks is the point — you change what is filtered by editing the prefix list, without touching the policy.

Because this pattern deploys **no attachments**, nothing carries the `vpcAttachment` label, so the rule never fires and the routing policy is **inert**. It is here to prove the alias resolves and the policy is accepted, which is what the pattern is teaching. To watch it actually drop a route you need a VPC attachment that carries the label and advertises one of the aliased prefixes.

The alias appears in four places that must agree: the policy documents, `var.prefix_list_alias` in Terraform, `PREFIX_LIST_ALIAS` in the CloudFormation `Makefile`, and the `PrefixListAlias` parameter default in `cloudformation/prefix_list.yaml`. Nothing validates that they do — a mismatch shows up as Cloud WAN rejecting the second policy.

## Verifying it works

1. Confirm the association exists and is available: `aws networkmanager list-core-network-prefix-list-associations --core-network-id <id> --region us-west-2`. Creating or deleting an association moves the core network to `UPDATING` first, so wait for it to settle.
2. Confirm the live policy is the one with the routing policy: `aws networkmanager get-core-network-policy --core-network-id <id> --region us-west-2` and look for the `routing-policies` block.
3. **Reproduce the failure on purpose.** This is the most useful step. Point a deploy at `baseline_prefix_list.json` on a core network that has no association yet, or reference an alias that does not exist, and watch Cloud WAN reject the policy. That error is the reason this pattern is split in two.

With Terraform, step 3 is:

```bash
terraform apply -var policy_document=../baseline_prefix_list.json
```

which asks for a core network to be *created* with the policy that names the alias, before any association can exist.

> **Deployed a policy of your own?** Steps 1 and 2 still apply. Step 3 is the interesting one either way: whatever your policy references, the alias has to be associated before the policy that names it is applied. That ordering is a property of Cloud WAN, not of this blueprint.

## Cost

| Resource | Count | Charged |
|----------|-------|---------|
| Core Network Edge | 2, one per edge location in the policy | Hourly |
| Managed prefix list | 1 | **Free** |
| Prefix list association | 1 | **Free** |

The two Core Network Edges are the entire bill, and they exist as soon as the policy declares its edge locations, whether or not anything is attached. Prefix lists and their associations cost nothing, so the only way to make this pattern cheaper is fewer edge locations. Use a non-production account and run the cleanup steps in the IaC README when you are finished.
