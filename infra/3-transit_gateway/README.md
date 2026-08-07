# Infra pattern 3 — Transit Gateway

Spoke VPCs attached to a **Transit Gateway** in each Region, with each Transit Gateway **peered to the Cloud WAN core network**. This is the coexistence and migration path — and because Transit Gateway route-table attachments speak BGP, it is also the cheapest way to exercise the BGP-dependent policy capabilities.

<!-- DIAGRAM PLACEHOLDER -->
> _Architecture diagram to be added._

## Implementations

| IaC | Directory | Notes |
|-----|-----------|-------|
| Terraform | [`terraform/`](./terraform/) | One `apply` |
| CloudFormation | [`cloudformation/`](./cloudformation/) | Core network stack, then a workload stack per Region |

New to the repository? Read [`../README.md`](../README.md) first — it covers prerequisites, cost, the tagging contract, and how to deploy a pattern with your own policy instead of its baseline.

## What gets deployed

| Component | Configuration |
|-----------|---------------|
| AWS Regions | `us-east-1`, `eu-west-1` |
| Core network | One, with a Core Network Edge in each Region |
| Transit Gateway | One per Region, ASN `64532` and `64533` |
| Transit Gateway route tables | Two per Region — `production`, `development` |
| Cloud WAN peering | One per Region, plus a Transit Gateway policy table |
| Route-table attachments | One `transit-gateway-route-table` attachment per route table |
| Spoke VPCs | Two per Region — `prod`, `dev` — attached to the **Transit Gateway**, not to Cloud WAN |
| Compute | An EC2 instance in every configured Availability Zone, plus an EC2 Instance Connect endpoint |

**Attachment types created:** `transit-gateway-route-table`. The spoke VPCs are **not** Cloud WAN attachments — they attach to the Transit Gateway, and the Transit Gateway attaches to Cloud WAN.

## The path a packet takes

Traffic takes two more hops than in [`1-basic`](../1-basic/):

```
VPC  ->  TGW attachment  ->  TGW route table  ->  TGW/Cloud WAN peering
     ->  transit-gateway-route-table attachment  ->  Cloud WAN segment
```

Each Transit Gateway route table becomes exactly one Cloud WAN attachment. So **a route table is the unit that maps onto a segment**, and which route table a VPC associates with decides which segment it reaches through.

Default route table association and propagation are **disabled** on the Transit Gateway, so every association is explicit. Implicit default-route-table behaviour is the usual cause of "why can these two VPCs reach each other" surprises in a segmented design.

## Attachment tags applied

| Attachment | Tag | Result |
|------------|-----|--------|
| `production` route table | `domain = production` | Joins the `production` segment |
| `development` route table | `domain = development` | Joins the `development` segment |

The spoke VPCs carry no Cloud WAN tags, because they are not Cloud WAN attachments.

The baseline matches `attachment-type = transit-gateway-route-table` **and** the `domain` tag, in a rule ahead of the VPC rule. The VPC rule is retained so the same policy still works if you later attach a VPC directly.

## ASN planning

The Transit Gateway ASNs — `64532` and `64533` — **must not overlap** the core network's `asn-ranges`, which the baseline sets to `64520-64525`. A Transit Gateway and a Core Network Edge sharing an ASN breaks BGP path selection in ways that present as intermittent blackholing rather than as an error.

Cloud WAN ASN ranges are **right-open**, so `64520-64525` provides 64520 to 64524. See [`policy/1-core_network_configuration.md`](../../policy/1-core_network_configuration.md).

## What the baseline policy demonstrates

[`baseline.json`](./baseline.json) is minimal: two segments, and the attachment rules that bind the route tables to them. There is no service insertion, so CloudFormation needs no multi-phase deploy.

| Source | Destination | Result | Why |
|--------|-------------|--------|-----|
| `prod` (us-east-1) | `prod` (eu-west-1) | Allowed | Both route tables land in `production`, which is global |
| `dev` (us-east-1) | `dev` (eu-west-1) | Allowed | Same, via `development` |
| `prod` | `dev` (same Region) | Blocked | Different route tables **and** different segments |
| `prod` | `dev` (cross-Region) | Blocked | No segment sharing declared |

Note which layer does which job: intra-Region separation comes from the **Transit Gateway** route tables, cross-Region separation comes from the **Cloud WAN** segments. Both are doing work, and a design that changes one without the other will surprise you.

## What this pattern can and cannot exercise

Transit Gateway route-table attachments are BGP-capable, so this pattern reaches capabilities that [`1-basic`](../1-basic/) and [`2-inspection`](../2-inspection/) cannot.

| Capability | Supported here |
|------------|----------------|
| Route summarization | Yes, outbound only — aggregate VPC prefixes before advertising to the Transit Gateway |
| Path preferences (AS_PATH, MED, local preference) | Yes |
| Route filtering on a peered Transit Gateway | Yes — for example, allow only IPv6 between Regions during a migration |
| BGP communities | **No.** Unsupported on Transit Gateway peering; use [`4-hybrid`](../4-hybrid/) |

One constraint is specific to this pattern: **route-table attachments that share a peering and land in the same segment share their outbound routing policies.** Attach two route tables from the same Transit Gateway to the same segment and a policy applied to one applies to both. Keeping one route table per segment avoids it.

To inspect traffic between Transit-Gateway-attached spokes, add inspection to this pattern — see [Choosing one](../README.md#the-patterns) for what that involves. Remember the two prerequisites: the participating segment must be isolated, and appliance mode must be enabled on the inspection VPC attachment.

## Verifying it works

1. In Network Manager, confirm two `transit-gateway-route-table` attachments per Region, each associated with the segment matching its `domain` tag.
2. In the Transit Gateway console, confirm each spoke VPC attachment is associated with the expected route table and propagating into it.
3. Connect to a spoke instance with EC2 Instance Connect and `ping` its cross-Region counterpart in the same segment. It should succeed.
4. `ping` across segments. It should fail.

If cross-Region traffic fails, check the Transit Gateway route table has a route for the remote prefix via the peering attachment. Propagation from Cloud WAN into the Transit Gateway route table is the step most often missed.

## Cost

| Resource | Count | Charged |
|----------|-------|---------|
| Transit Gateway | 2, one per Region | Hourly per attachment, plus data processed |
| Transit Gateway VPC attachment | 4 | Hourly |
| Transit Gateway / Cloud WAN peering | 2 | Hourly |
| `transit-gateway-route-table` attachment | 4 | Hourly, per attachment |
| Core Network Edge | 2, one per Region | Hourly |
| EC2 instance | One per configured Availability Zone of every VPC | Hourly |
| EC2 Instance Connect endpoint | 4, one per VPC | Hourly |

The Transit Gateways dominate: every attachment is billed per hour and data crossing the Transit Gateway is billed per GB, so traffic between Regions is charged by both the Transit Gateway and Cloud WAN.

Use a non-production account and run the cleanup steps in the IaC README when you are finished.
