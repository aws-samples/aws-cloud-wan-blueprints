# Infra pattern 5 — Multi-account

A global network, a core network, and an **AWS RAM share** — no workloads.

This is the pattern for Cloud WAN's multi-account capabilities: sharing a core network with other accounts, controlling who may attach to which segment, and working around the limitations that appear once attachments are created by accounts that do not own the policy.

<!-- DIAGRAM PLACEHOLDER -->
> _Architecture diagram to be added._

## Implementations

| IaC | Directory | Notes |
|-----|-----------|-------|
| Terraform | [`terraform/`](./terraform/) | One `apply`; name the principals with `-var` |
| CloudFormation | [`cloudformation/`](./cloudformation/) | Core network stack, then the RAM share stack |

New to the repository? Read [`../README.md`](../README.md) first — it covers prerequisites, cost, the tagging contract, and how to deploy a pattern with your own policy instead of its baseline.

## What gets deployed

Everything runs in the **networking account**.

| Component | Configuration |
|-----------|---------------|
| AWS Regions | `us-east-1`, `eu-west-1` |
| Global network | One |
| Core network | One, with a Core Network Edge in each Region |
| AWS RAM resource share | The core network, shared with the principals you name |

**Attachment types created:** none. The spoke accounts create the attachments.

## The RAM resources

Sharing the core network is all this pattern adds on top of the core network itself — three resources in Terraform, one in CloudFormation:

| Purpose | CloudFormation | Terraform |
|---------|----------------|-----------|
| The share itself | `AWS::RAM::ResourceShare` (principals and the core network ARN are properties) | `aws_ram_resource_share` |
| Put the core network in the share | *(a property of the share)* | `aws_ram_resource_association` |
| Grant a principal access | *(a property of the share)* | `aws_ram_principal_association` |

A principal can be an AWS account ID, an organizational unit ARN, or an organization ARN.

## Adding workloads

Deploy any other pattern's workload code in the spoke account. The workload code is identical to the single-account case — it points at a core network it did not create, using the `core_network_id` and `core_network_arn` outputs from here.

Sharing is orthogonal to topology: anything you can build in one account you can build across accounts, so combine this pattern with inspection, Transit Gateway, or hybrid connectivity as needed.

## What the baseline policy demonstrates

[`baseline.json`](./baseline.json) is [`1-basic`](../1-basic/)'s policy with two differences, both of which only matter across accounts.

**First, `production` requires attachment acceptance and `development` does not.**

```json
{
  "segments": [
    { "name": "production", "require-attachment-acceptance": true },
    { "name": "development", "require-attachment-acceptance": false }
  ]
}
```

In a single account that distinction is ceremony, since you own both sides. Across accounts it is the control that stops a spoke team placing a workload into a sensitive segment.

**Second, the attachment policies are ordered** so `development` is matched by an explicit `tag-value` rule *before* the general tag-based rule:

```json
{
  "attachment-policies": [
    {
      "rule-number": 100,
      "condition-logic": "and",
      "conditions": [
        { "type": "attachment-type", "operator": "equals", "value": "vpc" },
        { "type": "tag-value", "operator": "equals", "key": "domain", "value": "development" }
      ],
      "action": { "association-method": "constant", "segment": "development" }
    },
    {
      "rule-number": 200,
      "condition-logic": "and",
      "conditions": [
        { "type": "attachment-type", "operator": "equals", "value": "vpc" },
        { "type": "tag-exists", "key": "domain" }
      ],
      "action": { "association-method": "tag", "tag-value-of-key": "domain" }
    }
  ]
}
```

Self-service into `development` is frictionless. Anything else falls through to rule 200 and, for `production`, then waits for acceptance.

## Cross-account limitations

Most of these are not obvious until they bite.

### Attachment tags are set by the attachment owner

With `association-method: tag`, the segment an attachment joins is decided by a tag value set **by the account that created the attachment**. Tag-based association therefore delegates segment choice across a trust boundary.

Within one account that is fine: you set the tag, you chose the segment. Across accounts it means a spoke team can request any segment simply by tagging. Three ways to constrain it:

1. **Constrain by `account-id`**, so a tag from an unexpected account matches nothing:

   ```json
   {
     "rule-number": 300,
     "condition-logic": "and",
     "conditions": [
       { "type": "tag-exists", "key": "domain" },
       { "type": "account-id", "operator": "equals", "value": "111122223333" }
     ],
     "action": { "association-method": "tag", "tag-value-of-key": "domain" }
   }
   ```

2. **`require-attachment-acceptance: true`** on sensitive segments, so a human in the networking account approves the association.

3. **Use `constant` for sensitive segments.** Give `production` an explicit rule keyed on account and Region, and reserve tag-based self-service for segments where a wrong answer is harmless.

See [`policy/3-attachment_policies.md`](../../policy/3-attachment_policies.md).

### Share scope: prefer accounts and OUs over the whole Organization

Sharing a core network grants the ability to create attachments into its segments. Share with specific account IDs, or with an organizational unit ARN, rather than an entire organization ARN. An organization-wide share means every account that joins the organization in future gains that ability without anybody deciding it.

### Acceptance depends on Organization membership

If the spoke account is in the same AWS Organization **with RAM sharing enabled**, the share is auto-accepted. Otherwise set `allow_external_principals = true` and the spoke account must accept the invitation. This is a frequent first-run stumble: the share appears created, and the spoke account simply cannot see the core network.

### Teardown is ordered across account boundaries

A core network with attachments from another account **cannot be deleted**, and the error does not point at the cause. Delete the spoke accounts' attachments first, then the core network. In a multi-team environment that ordering is a coordination problem, not just a command sequence.

### Visibility is asymmetric

A spoke account can see the core network it is attached to, but not the policy document, the other accounts' attachments, or the segments it is not associated with. Design accordingly: spoke teams cannot self-diagnose why their attachment did not associate, so the networking account owns that runbook. The most common cause is a `domain` tag that matches no rule in a policy the spoke team cannot read.

## Verifying it works

1. In the networking account, confirm the RAM share exists and lists the expected principals.
2. In the spoke account, confirm the core network is visible with `aws networkmanager list-core-networks`. If it is not, the RAM invitation has not been accepted.
3. Create a VPC attachment in the spoke account tagged `domain = development`. It should associate automatically.
4. Create one tagged `domain = production`. It should sit **pending acceptance** until approved from the networking account — that is `require-attachment-acceptance` doing its job.

## Cost

**The cheapest pattern here.**

| Resource | Count | Charged |
|----------|-------|---------|
| Core Network Edge | 2, one per Region | Hourly |
| AWS RAM resource share | 1 | **Free** |

That is the entire bill for the networking account — this pattern creates no VPCs, no instances, and no attachments. Anything the spoke accounts attach is billed to the spoke accounts, including their VPC attachment hours.

Note that Core Network Edges are charged from the moment the core network exists, whether or not anything is attached to it. Use a non-production account and run the cleanup steps in the IaC README when you are finished.
