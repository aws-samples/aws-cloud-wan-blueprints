# Infrastructure-as-Code Patterns — AWS Cloud WAN with hybrid connectivity

In this pattern, we want to show how AWS Cloud WAN integrates with AWS Site-to-Site VPN and AWS Direct Connect to achieve hybrid connectivity.

> **Connect (SD-WAN) attachments are not covered yet.** This pattern ships Site-to-Site VPN and Direct Connect gateway attachments. Support for Connect attachments is on the way.

![Hybrid architecture](../../images/4-hybrid.png)

## Implementations

| IaC | Directory |
|-----|-----------|
| Terraform | [`terraform/`](./terraform/) |
| CloudFormation | [`cloudformation/`](./cloudformation/) |

> New to the repository? Read [`../README.md`](../README.md) first.

## What gets deployed

| Component | Configuration |
|-----------|---------------|
| AWS Regions | `us-east-1`, `eu-west-1` |
| AWS Cloud WAN resources | Global network & core network, with the Core Network Edge ASNs pinned to `64520` and `64521` |
| Spoke VPCs | One per Region, each with three subnet tiers, one of them for the Cloud WAN attachment |
| Site-to-Site VPN | Optional, in `us-east-1` — a customer gateway, a VPN connection, and its Cloud WAN attachment |
| Direct Connect gateway | Optional — the direct connect gateway and its Cloud WAN attachment, which reaches both Core Network Edges |
| Compute | An EC2 instance in every configured Availability Zone of each spoke VPC, plus an EC2 Instance Connect endpoint per VPC |

**Attachment types created:** `vpc`, plus `site-to-site-vpn` and `direct-connect-gateway` when you enable them. Both hybrid attachments are off by default, because each needs a value only you can supply.

**No attachment tags are applied.** Every other pattern here tags its attachments so the policy can associate on the tag value. This one does not: the baseline matches on **attachment type** and associates by a constant segment, so there is nothing for a tag to match. A Direct Connect gateway attachment is hybrid connectivity by definition and its owner has no segment choice to express, which is what makes attachment-type association the natural fit.

The customer gateway ASN and the Direct Connect gateway's Amazon-side ASN must not overlap the core network's `asn-ranges`, which the baseline sets to `64520-64525`.

> **This pattern builds the AWS side only.** The VPN tunnels stay down until a real on-premises peer answers, and the Direct Connect gateway carries no traffic until you associate a Transit VIF with it — creating the Transit VIFs and their association is out of scope here. What you can verify is the integration itself: that each hybrid attachment reaches the `hybrid` segment. Testing the path end to end is yours to do.

## What the baseline policy configures

[`baseline.json`](./baseline.json) separates workloads from hybrid connectivity, then shares one with the other.

| | |
|---|---|
| Segments | `vpcs` and `hybrid`, both non-isolated |
| Association | Rule 100 matches `site-to-site-vpn` **or** `direct-connect-gateway` and lands them in `hybrid`; rule 200 matches `vpc` and lands them in `vpcs`. Both associate by constant |
| Sharing | `vpcs` is shared with `hybrid` |
| Core network | `vpn-ecmp-support` and `dns-support` both enabled |

Resulting reachability:

| Source | Destination | Result | Why |
|--------|-------------|--------|-----|
| spoke (us-east-1) | spoke (eu-west-1) | Allowed | Same `vpcs` segment, non-isolated, and segments are global |
| spoke VPC | Either hybrid attachment | Allowed | `vpcs` is shared with `hybrid` |
| VPN | Direct Connect gateway | Allowed | Both land in `hybrid`, which is not isolated |

Only the first row is testable here — the other two describe what the policy permits once a real hybrid path exists.

## Verifying it works

1. In the AWS Network Manager console, confirm each spoke VPC attachment is `AVAILABLE` and associated with the `vpcs` segment, **with no tag applied**. That is attachment-type association working.
2. For whichever hybrid attachments you enabled, confirm the same: `AVAILABLE` and associated with `hybrid`.
3. Connect to an instance with EC2 Instance Connect — the endpoint sits in each VPC's endpoints subnet.
4. `ping` the instance in the other Region. It should succeed: both spokes are in `vpcs`.

> **Deployed a policy of your own?** Steps 1 to 3 still apply — every attachment has to be `AVAILABLE` and associated where you expect. Step 4 does not: that describes the baseline, so derive your own expectations from the segments and `share` actions you wrote. Beyond reachability, what to check depends on the capabilities you used, and the [`policy/`](../../policy/) pages cover them.

If an attachment is `AVAILABLE` but shows no segment, the policy's attachment policies do not match it. Because this pattern associates on attachment type rather than on a tag, check the `attachment-type` conditions rather than looking for a missing tag. See [`policy/3-attachment_policies.md`](../../policy/3-attachment_policies.md).

## Cost

| Resource | Count | Charged |
|----------|-------|---------|
| Core Network Edge | 2, one per Region | Hourly |
| VPC attachment | 2, one per Region | Hourly, per attachment |
| Site-to-Site VPN connection | 0 or 1 | Hourly, plus data transferred |
| Site-to-Site VPN attachment | 0 or 1 | Hourly, per attachment |
| Direct Connect gateway | 0 or 1 | **Free** |
| Direct Connect gateway attachment | 0 or 1 | Hourly, per attachment |
| EC2 instance | One per configured Availability Zone of every VPC | Hourly |
| EC2 Instance Connect endpoint | 2, one per VPC | Hourly |

Use a non-production account and run the cleanup steps in the IaC README when you are finished.
