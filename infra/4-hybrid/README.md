# Infra pattern 4 — Hybrid

Adds **hybrid connectivity** to [`1-basic`](../1-basic/): AWS Site-to-Site VPN, Connect (SD-WAN), and Direct Connect gateway, each independently optional. This is the only pattern that unlocks the full BGP capability surface — route summarization, path preferences, and BGP communities.

<!-- DIAGRAM PLACEHOLDER -->
> _Architecture diagram to be added._

## Implementations

| IaC | Directory | Covers |
|-----|-----------|--------|
| Terraform | [`terraform/`](./terraform/) | Everything, including the hybrid attachments and the prefix lists |
| CloudFormation | [`cloudformation/`](./cloudformation/) | Core network and spoke VPCs only |

The hybrid attachments and prefix lists are **Terraform-only**, because each sub-type is enabled selectively and that maps cleanly onto Terraform's optional object variables but awkwardly onto CloudFormation `Conditions`. The policy side is identical either way — attachment-type association is in the generated `core_network.yaml` — so a hybrid attachment created by hand against a CloudFormation deployment still lands in the `hybrid` segment automatically.

New to the repository? Read [`../README.md`](../README.md) first — it covers prerequisites, cost, the tagging contract, and how to deploy a pattern with your own policy instead of its baseline.

## What gets deployed

| Component | Configuration |
|-----------|---------------|
| AWS Regions | `us-east-1` and `eu-west-1` as edge locations, plus `us-west-2` for prefix lists only |
| Core network | One, with **pinned** Core Network Edge ASNs (`64520`, `64521`) and `inside-cidr-blocks` for Connect |
| Spoke VPCs | Two per Region — `prod`, `dev` |
| Hybrid attachments | Site-to-Site VPN, Connect, Direct Connect gateway — each optional, **all off by default** |
| Managed prefix lists | Two, created in `us-west-2` and associated with the core network under aliases |
| Compute | An EC2 instance in every configured Availability Zone, plus an EC2 Instance Connect endpoint |

**Attachment types created:** `vpc`, plus whichever of `site-to-site-vpn`, `connect`, and `direct-connect-gateway` you enable.

## What each sub-type needs before it does anything

Every policy capability treats the three sub-types identically. What differs is what each needs before routes appear.

| Sub-type | Deploys with no external kit? | To actually exchange routes you need |
|----------|-------------------------------|--------------------------------------|
| Site-to-Site VPN | Yes | A BGP-speaking peer at the customer gateway address. Without one, the attachment exists and the tunnels stay **DOWN** |
| Connect (SD-WAN) | The attachment, yes; the peer, no | An underlay VPC attachment (provided), `inside-cidr-blocks` in the policy (provided), and an appliance address for the peer |
| Direct Connect gateway | The gateway and attachment, yes | A **real** Direct Connect connection and virtual interface. This cannot be simulated |

The useful consequence: with no on-premises equipment at all you can still deploy the VPN and Direct Connect gateway attachments and watch them associate to the `hybrid` segment. That demonstrates attachment-type association and lets you bind routing-policy labels to them. You just will not see routes.

## Attachment tags applied

| Attachment | Tag | Binds via |
|------------|-----|-----------|
| `prod` VPC | `domain = production` | Tag value |
| `dev` VPC | `domain = development` | Tag value |
| VPN, Connect, Direct Connect gateway | *(none)* | `attachment-type` |

Hybrid attachments are associated by **attachment type rather than by tag**. The baseline matches all three with one rule:

```json
{
  "rule-number": 100,
  "condition-logic": "or",
  "conditions": [
    { "type": "attachment-type", "operator": "equals", "value": "site-to-site-vpn" },
    { "type": "attachment-type", "operator": "equals", "value": "connect" },
    { "type": "attachment-type", "operator": "equals", "value": "direct-connect-gateway" }
  ],
  "action": { "association-method": "constant", "segment": "hybrid" }
}
```

A Direct Connect gateway attachment is hybrid connectivity by definition, so its owner has no segment choice to express. A VPC could belong to any segment, so it declares its intent with a `domain` tag. [`policy/3-attachment_policies.md`](../../policy/3-attachment_policies.md) covers when each binding method is correct.

## What the baseline policy demonstrates

[`baseline.json`](./baseline.json) creates `production`, `development`, and `hybrid` segments, binds attachments as above, and shares `hybrid` with everything:

```json
{
  "action": "share",
  "mode": "attachment-route",
  "segment": "hybrid",
  "share-with": "*"
}
```

`share-with: "*"` suits hybrid: on-premises usually needs to reach every workload segment, and enumerating them means editing the policy each time one is added. Be aware that `"*"` also picks up segments added in future, which is rarely what you want elsewhere. See [`policy/4-segment_sharing.md`](../../policy/4-segment_sharing.md).

The core network also **pins** its Core Network Edge ASNs — `64520` for `us-east-1`, `64521` for `eu-west-1`. Pinning matters as soon as you write AS_PATH-based routing policies, because it makes the AS_PATH predictable and the policy readable. Hybrid ASNs must not overlap the core network's `asn-ranges`, and remember the range is right-open, so `64520-64525` provides 64520 to 64524.

## Prefix lists for route summarization

Summarization matches on **managed prefix lists by alias**, and those prefix lists must be created in Cloud WAN's home Region, `us-west-2`, regardless of where the edge locations are. That is the only reason this pattern has a third provider alias for a Region that hosts no Core Network Edge.

| Alias | Contains |
|-------|----------|
| `nvirginiaipv4routes` | The `us-east-1` spoke VPC CIDRs |
| `irelandipv4routes` | The `eu-west-1` spoke VPC CIDRs |

One list per Region rather than a single aggregate, because a Direct Connect gateway attaches to **every** Core Network Edge. Advertise one supernet from every edge and on-premises routers see equal-cost paths into any Region, so traffic for an `eu-west-1` workload can enter through `us-east-1` and cross the backbone. Per-Region supernets keep entry local. See [`policy/6-routing_policies.md`](../../policy/6-routing_policies.md#route-summarization).

Set `create_prefix_lists = false` to skip them. They are free, and a summarization policy has nothing to match without them, so the default is on.

## What this pattern can and cannot exercise

| Capability | Supported here |
|------------|----------------|
| Route filtering | Yes, inbound and outbound, on any hybrid attachment |
| Route summarization | Yes, outbound only, using the prefix list aliases above |
| Path preferences (AS_PATH, MED, local preference) | Yes — the reason the CNE ASNs are pinned |
| BGP communities | VPN and Connect, yes. Direct Connect gateway and Transit Gateway peering, **no** — `tools/validate_policy.py` warns with `cwan-11` |

## Verifying it works

With no on-premises equipment:

1. In Network Manager, confirm the hybrid attachment appears and is associated with the `hybrid` segment **with no tag applied**. That is attachment-type association working.
2. Confirm the prefix list associations exist on the core network under the expected aliases.
3. Apply a routing-policy label to the hybrid attachment and confirm a routing policy binds to it.

With a BGP peer:

4. Confirm the VPN tunnels come up and that routes appear from on-premises.
5. Apply a summarization policy and check the on-premises router receives the supernet rather than the individual VPC CIDRs.
6. Verify with `get-network-routes`, **not** `list-core-network-routing-information` — the latter shows state *before* routing policies are applied, so it will happily show you the unsummarized routes and look like a failure.

## Cost

| Resource | Count | Charged |
|----------|-------|---------|
| Core Network Edge | 2, one per Region | Hourly |
| VPC attachment | 4 | Hourly, per attachment |
| Site-to-Site VPN attachment | 0 or 1 | Hourly, plus data transferred |
| Connect attachment | 0 or 1 | Hourly |
| Direct Connect gateway attachment | 0 or 1 | Hourly |
| Managed prefix list | 2 | **Free** |
| EC2 instance | One per configured Availability Zone of every VPC | Hourly |
| EC2 Instance Connect endpoint | 4, one per VPC | Hourly |

With no hybrid sub-type enabled — the default — this costs the same as [`1-basic`](../1-basic/) with four VPCs instead of six. Each sub-type you enable adds attachment hours from the moment it is created, whether or not a peer is ever configured, so a VPN attachment with dead tunnels still bills.

A Direct Connect **circuit** dwarfs everything above and is outside this pattern: you bring your own.

Use a non-production account and run the cleanup steps in the IaC README when you are finished.
