---
title: "Cloud WAN service insertion: send-to and send-via for centralized traffic inspection"
description: "How to steer AWS Cloud WAN traffic through a firewall, with send-to for internet-bound egress and send-via for east-west, choosing between single-hop and dual-hop, and pinning which Region inspects a flow with with-edge-overrides. Includes the segment and network function group route tables each action builds, and the constraints on mixing modes."
---

# Service insertion

[Service insertion](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-service-insertion.html) places a security appliance in the traffic path without you managing the routing that makes it happen. You declare which traffic should be inspected, through which group of appliances, and in which Regions. AWS Cloud WAN builds and maintains the routes that redirect traffic through the appliance and back — dynamically, as attachments join and leave the core network.

Two building blocks make this work. A [network function group](./2-segments-and-nfg.md#network-function-groups) holds the inspection attachments — the appliance side. A `send-to` or `send-via` segment action steers a segment's traffic through that group — the intent side.

> **An attachment is in a segment or in an NFG, never both.** inspection VPCs need their own low-numbered [attachment-policy rule](./3-attachment_policies.md#action) ahead of any broader one that would otherwise claim them as a plain `vpc`.

> **Appliance mode is required on every inspection VPC attachment.** It pins both directions of a flow to the same Availability Zone, and so the same firewall endpoint — without it, the return path can land on a different endpoint with no state for the flow, and the flow is dropped.

## Service insertion actions

Every field a service insertion entry accepts:

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `action` | Which segment action this entry is — `send-to` or `send-via` | Yes | `share` |
| `mode` | How `send-via` traffic reaches the NFG — `single-hop` or `dual-hop` | `send-via` only | — |
| `segment` | The segment whose traffic is redirected | Yes | — |
| `when-sent-to` | Which destination segments `send-via` applies to | `send-via` only | — |
| `via` | The network function group, and any edge overrides | Yes | — |

The snippets below build progressively — by the time you reach `via`, you are looking at a complete action.

### `action`

Two actions, two traffic patterns:

| Action | Inspects | Use when |
|--------|----------|----------|
| `send-to` | Traffic **leaving** the network — internet-bound | You need centralized egress inspection through a firewall before traffic exits |
| `send-via` | Traffic **inside** the network — intra-segment, inter-segment, or hybrid (anything that lands in a segment) | You need east-west inspection between workloads, or between workloads and on-premises |

```json
{
  "action": "send-to"
}
```

```json
{
  "action": "send-via"
}
```

> **`send-to` requires the inspection VPC to carry the full egress path.** The NFG attachment is the last hop inside the core network — traffic exits through whatever the inspection VPC provides after the firewall: NAT gateways, internet gateways.

[How routing is built](#how-routing-is-built) explains what each action and mode produces in the segment and NFG route tables. There are some limitations when working with both actions at the same time in the network, check [Constraints and workarounds](#constraints-and-workarounds). See [`via`](#via) for when to set `with-edge-overrides`.

### `mode`

`send-via` only. When traffic traverses two AWS Regions, `mode` decides whether it is inspected in one Region or both. Two modes, two behaviours:

| Mode | Inspects | Traffic path |
|------|----------|--------------|
| `dual-hop` | In **both** the source and destination Region | VPC (us-east-1) → firewall (us-east-1) → firewall (eu-west-1) → VPC (eu-west-1) |
| `single-hop` | In **one** Region only | VPC (us-east-1) → firewall (us-east-1) → VPC (eu-west-1) |

**`dual-hop`** needs an inspection attachment in every Region the redirected segments touch — a Region without one blackholes the traffic. It adds latency from two inspection hops, but there are reasons to want both: different teams managing each Region's firewall policy, a compliance mandate requiring traffic inspected at both ends, or simply wanting each Region's firewall logs to reflect all the traffic that originated or terminated there.

```json
{
  "action": "send-via",
  "mode": "dual-hop"
}
```

**`single-hop`** inspects once, in one of the two Regions. Lower latency, lower cost, and the only way to let a Region with no local inspection VPC participate. It fits when a single centralized firewall policy governs all Regions, when cross-Region latency is a concern, or when not every Region justifies a full firewall deployment.

```json
{
  "action": "send-via",
  "mode": "single-hop"
}
```

[How routing is built](#how-routing-is-built) explains the route tables each mode produces. There are constraints when mixing modes — check [Constraints and workarounds](#constraints-and-workarounds). Always pair `single-hop` with `with-edge-overrides` — see [`via`](#via) for why.

### `segment`

The segment whose traffic enters the inspection path — the **source**. Whatever this segment's attachments send toward the destinations named in [`when-sent-to`](#when-sent-to) (for `send-via`) or toward the internet (for `send-to`) is what gets redirected through the NFG. One name, no array — a second segment needing the same treatment is a second entry.

```json
{
  "action": "send-to",
  "segment": "production"
}
```

```json
{
  "action": "send-via",
  "mode": "dual-hop",
  "segment": "production"
}
```

### `when-sent-to`

`send-via` only. Which destination segments the redirect applies to.

```json
{
  "action": "send-via",
  "mode": "dual-hop",
  "segment": "production",
  "when-sent-to": { "segments": "*" }
}
```

| Value | Inspects |
|-------|----------|
| `{ "segments": "*" }` | Traffic from `segment` to **any** segment, including itself |
| `{ "segments": ["development"] }` | Only traffic from `segment` to `development` |
| *(omitted)* | Only traffic within `segment` itself — equivalent to `{ "segments": ["<segment>"] }` |

Whether `when-sent-to` includes the source segment itself determines whether isolation is needed:

- **Intra-segment** (`"*"`, `segment`'s own name in the list, or `when-sent-to` omitted entirely): requires [`isolate-attachments: true`](./2-segments-and-nfg.md#isolate-attachments) on the source segment. Without it, segment's route table has a direct route between attachments — the NFG never sees the traffic.
- **Inter-segment only** (lists segments other than the source): no isolation needed. There is no direct route between segments to begin with, so there is nothing to bypass.

### `via`

Names the network function group traffic is redirected through, and — when a choice of Region exists — which one does the inspecting. `via` accepts two fields:

| Field | What it sets | Required |
|-------|--------------|----------|
| `network-function-groups` | The NFG traffic is redirected through | Yes |
| `with-edge-overrides` | Which Region inspects which flow | No — but recommended for `send-to` and `single-hop` |

**`network-function-groups`** names the NFG traffic is redirected through. One group per action.

```json
{
  "action": "send-via",
  "mode": "dual-hop",
  "segment": "production",
  "when-sent-to": { "segments": "*" },
  "via": {
    "network-function-groups": ["inspectionVpcs"]
  }
}
```

**`with-edge-overrides`** makes the inspection-Region choice explicit rather than leaving it to AWS Cloud WAN's default priority list. Each override entry carries:

| Element | Meaning |
|---------|---------|
| `edge-sets` | A Region pair — source and destination of the flow being overridden |
| `use-edge-location` | The Region that inspects both directions of that pair |
| Single-Region `edge-sets` (e.g. `[["eu-west-2"]]`) | Traffic starting and ending in that Region — used when it has no local inspection VPC |

**`send-to` with a Region that has no local inspection VPC:**

```json
{
  "action": "send-to",
  "segment": "production",
  "via": {
    "network-function-groups": ["inspectionVpcs"],
    "with-edge-overrides": [
      {
        "edge-sets": [["eu-west-2"]],
        "use-edge-location": "eu-west-1"
      }
    ]
  }
}
```

Egress traffic from `eu-west-2` is inspected in `eu-west-1`, because `eu-west-2` has no inspection VPC of its own.

**`send-via` single-hop:**

```json
{
  "action": "send-via",
  "mode": "single-hop",
  "segment": "production",
  "when-sent-to": { "segments": "*" },
  "via": {
    "network-function-groups": ["inspectionVpcs"],
    "with-edge-overrides": [
      {
        "edge-sets": [["us-east-1", "eu-west-1"]],
        "use-edge-location": "us-east-1"
      },
      {
        "edge-sets": [["eu-west-2"]],
        "use-edge-location": "eu-west-1"
      }
    ]
  }
}
```

Cross-Region traffic between `us-east-1` and `eu-west-1` is inspected in `us-east-1`. Traffic starting and ending in `eu-west-2` is inspected in `eu-west-1`, since `eu-west-2` has no local inspection VPC.

Every Region named must already be a declared edge location — AWS Cloud WAN validates this at policy generation.

> **Use `with-edge-overrides` for `send-to` and `single-hop`.** Without them, AWS Cloud WAN picks the inspection Region from a default priority list — opaque, not visible in the policy, and liable to change as Regions are added. `dual-hop` inspects in both Regions by definition and needs no overrides.

With more than two Regions the overrides become a matrix (every source paired with every destination), which is worth drawing before writing JSON.

## How routing is built

Cloud WAN writes to two route tables for every service insertion action — the **segment route table** (where traffic enters the inspection path) and the **NFG route table** (where inspected traffic exits toward its destination). Both are maintained automatically as attachments join and leave. The prose below each snippet explains why each entry exists; the tables show what you would see in `get-network-routes`.

### `send-to`

Cloud WAN installs a default route — both `0.0.0.0/0` and `::/0`, regardless of whether IPv6 is in use — in the segment, pointing at the local NFG attachment if one exists in that Region, or at the one specified in `with-edge-overrides` (falling back to Cloud WAN's default priority list if neither is configured). The NFG route table gets propagated the segment's attachment routes, so the appliance can route return traffic back to the originating workload.

In this example, `us-east-1` and `eu-west-1` have inspection VPCs, but `eu-south-2` does not — its egress is overridden to `eu-west-1`:

```json
{
  "segments": [
    {
      "name": "production",
      "require-attachment-acceptance": false
    }
  ],
  "segment-actions": [
    {
      "action": "send-to",
      "segment": "production",
      "via": {
        "network-function-groups": ["inspectionVpcs"],
        "with-edge-overrides": [
          {
            "edge-sets": [["eu-south-2"]],
            "use-edge-location": "eu-west-1"
          }
        ]
      }
    }
  ]
}
```

**production segment — us-east-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (local) | VPC attachments |
| production VPCs (eu-west-1) | CNE peering |
| production VPCs (eu-south-2) | CNE peering |
| `0.0.0.0/0`, `::/0` | inspection VPC (us-east-1) |

**production segment — eu-west-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (local) | VPC attachments |
| production VPCs (us-east-1) | CNE peering |
| production VPCs (eu-south-2) | CNE peering |
| `0.0.0.0/0`, `::/0` | inspection VPC (eu-west-1) |

**production segment — eu-south-2:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (local) | VPC attachments |
| production VPCs (us-east-1) | CNE peering |
| production VPCs (eu-west-1) | CNE peering |
| `0.0.0.0/0`, `::/0` | inspection VPC (eu-west-1) |

**inspectionVpcs NFG — us-east-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (us-east-1) | VPC attachments |
| production VPCs (eu-west-1) | CNE peering |
| production VPCs (eu-south-2) | CNE peering |

**inspectionVpcs NFG — eu-west-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (eu-west-1) | VPC attachments |
| production VPCs (us-east-1) | CNE peering |
| production VPCs (eu-south-2) | CNE peering |

**inspectionVpcs NFG — eu-south-2:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (eu-south-2) | VPC attachments |
| production VPCs (us-east-1) | CNE peering |
| production VPCs (eu-west-1) | CNE peering |

### `send-via` dual-hop

Redirects every destination named in `when-sent-to` through the local NFG attachment. Cross-Region traffic hits the peer Region's inspection VPC as a second hop; intra-Region traffic is delivered directly after one hop.

In this example, `production` attachments reach each other directly — no isolation, no intra-segment inspection. Only traffic from `production` toward `development` is inspected, with inspection VPCs in both `us-east-1` and `eu-west-1`:

```json
{
  "segments": [
    {
      "name": "production",
      "require-attachment-acceptance": false
    },
    {
      "name": "development",
      "require-attachment-acceptance": false
    }
  ],
  "segment-actions": [
    {
      "action": "send-via",
      "segment": "production",
      "mode": "dual-hop",
      "when-sent-to": {
        "segments": ["development"]
      },
      "via": {
        "network-function-groups": ["inspectionVpcs"]
      }
    }
  ]
}
```

**production segment — us-east-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (us-east-1) | VPC attachments |
| production VPCs (eu-west-1) | CNE peering |
| development VPCs (us-east-1) | inspection VPC (us-east-1) |
| development VPCs (eu-west-1) | inspection VPC (us-east-1) |

**production segment — eu-west-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (eu-west-1) | VPC attachments |
| production VPCs (us-east-1) | CNE peering |
| development VPCs (eu-west-1) | inspection VPC (eu-west-1) |
| development VPCs (us-east-1) | inspection VPC (eu-west-1) |

**development segment — us-east-1:**

| Destination | Next hop |
|-------------|----------|
| development VPCs (us-east-1) | VPC attachments |
| development VPCs (eu-west-1) | CNE peering |
| production VPCs (us-east-1) | inspection VPC (us-east-1) |
| production VPCs (eu-west-1) | inspection VPC (us-east-1) |

**development segment — eu-west-1:**

| Destination | Next hop |
|-------------|----------|
| development VPCs (eu-west-1) | VPC attachments |
| development VPCs (us-east-1) | CNE peering |
| production VPCs (eu-west-1) | inspection VPC (eu-west-1) |
| production VPCs (us-east-1) | inspection VPC (eu-west-1) |

**inspectionVpcs NFG — us-east-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (us-east-1) | VPC attachments |
| production VPCs (eu-west-1) | CNE peering |
| development VPCs (us-east-1) | VPC attachments |
| development VPCs (eu-west-1) | inspection VPC (eu-west-1) — **second hop** |

**inspectionVpcs NFG — eu-west-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (eu-west-1) | VPC attachments |
| production VPCs (us-east-1) | CNE peering |
| development VPCs (eu-west-1) | VPC attachments |
| development VPCs (us-east-1) | inspection VPC (us-east-1) — **second hop** |

`production`'s own routes are unaffected — no redirect, since `when-sent-to` names only `development`. The same is true of `development`'s own attachments to each other: no `send-via` action names `development` as a source, so its local destinations route directly too. What `development`'s table does need is `production` routes redirected, since inspected traffic has to flow — and reply — in both directions.

### `send-via` single-hop

Intra-Region traffic uses the local inspection VPC. Cross-Region traffic uses whichever Region `with-edge-overrides` names for that pair, or Cloud WAN's default priority list if no override is configured. Either way there is only one hop, so the NFG table points every destination directly at the destination's attachment — no peer-Region redirect is needed.

> **A Region with no local inspection VPC still gets inspected — just not predictably, unless you say where.** Its own local traffic falls back to Cloud WAN's default priority list like any other cross-Region flow would. Use a single-Region `edge-sets` override to choose the Region explicitly instead of relying on the default.

In this example, intra-segment traffic is allowed without inspection and inter-segment is inspected. The override names only the **cross-Region pair** — traffic between Regions is inspected in `us-east-1`:

```json
{
  "segments": [
    {
      "name": "production",
      "require-attachment-acceptance": false
    },
    {
      "name": "development",
      "require-attachment-acceptance": false
    }
  ],
  "segment-actions": [
    {
      "action": "send-via",
      "segment": "production",
      "mode": "single-hop",
      "when-sent-to": {
        "segments": ["development"]
      },
      "via": {
        "network-function-groups": ["inspectionVpcs"],
        "with-edge-overrides": [
          {
            "edge-sets": [["us-east-1", "eu-west-1"]],
            "use-edge-location": "us-east-1"
          }
        ]
      }
    }
  ]
}
```

**production segment — us-east-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (us-east-1) | VPC attachments |
| production VPCs (eu-west-1) | CNE peering |
| development VPCs (us-east-1) | inspection VPC (us-east-1) |
| development VPCs (eu-west-1) | inspection VPC (us-east-1) — via override |

**production segment — eu-west-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (eu-west-1) | VPC attachments |
| production VPCs (us-east-1) | CNE peering |
| development VPCs (eu-west-1) | inspection VPC (eu-west-1) |
| development VPCs (us-east-1) | inspection VPC (us-east-1) — via override |

**inspectionVpcs NFG — us-east-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (us-east-1) | VPC attachments |
| production VPCs (eu-west-1) | CNE peering |
| development VPCs (us-east-1) | VPC attachments |
| development VPCs (eu-west-1) | CNE peering |

**inspectionVpcs NFG — eu-west-1:**

| Destination | Next hop |
|-------------|----------|
| production VPCs (eu-west-1) | VPC attachments |
| production VPCs (us-east-1) | CNE peering |
| development VPCs (eu-west-1) | VPC attachments |
| development VPCs (us-east-1) | CNE peering |

## Constraints and workarounds

### A network function group used by `dual-hop` cannot also be used for `single-hop` or `send-to`

`send-to` routing configuration behaves similarly as `send-via single-hop`: they need one unambiguous next hop per Region. However, `dual-hop` needs a *pair* of hops for the same flow — one route table can't hold both routing behaviours at once.

Give each action its own NFG instead — one for egress, one for east-west. That does not mean two firewalls: one inspection VPC per NFG, both pointed at the same underlying capacity. With AWS Network Firewall, [VPC endpoint associations](https://docs.aws.amazon.com/network-firewall/latest/developerguide/creating-vpc-endpoint-association.html) attach an additional firewall endpoint, in a different VPC, to an existing firewall. With Gateway Load Balancer (GWLB) and a third-party appliance, the equivalent is two GWLB endpoints pointed at the same firewall fleet.

```json
{
  "network-function-groups": [
    {
      "name": "egressVpcs",
      "require-attachment-acceptance": false
    },
    {
      "name": "eastWestVpcs",
      "require-attachment-acceptance": false
    }
  ],
  "segment-actions": [
    {
      "action": "send-to",
      "segment": "production",
      "via": {
        "network-function-groups": ["egressVpcs"]
      }
    },
    {
      "action": "send-via",
      "segment": "production",
      "mode": "dual-hop",
      "when-sent-to": { "segments": "*" },
      "via": {
        "network-function-groups": ["eastWestVpcs"]
      }
    }
  ]
}
```

`send-to` paired with `single-hop` **on the same NFG** has no such conflict — both resolve to one hop per flow, so the two can share a route table.

### A segment cannot mix `dual-hop` and `single-hop`

A segment can only use one `mode` for `send-via`, even across separate actions with different destinations. Your segment cannot be `dual-hop` toward one destination and `single-hop` toward another — pick the one mode it needs everywhere.

The only workaround is to split by **source**, not destination: if some attachments in the segment only ever need one mode and others only ever need the other, move the second group into its own segment with its own `send-via` action. This does not help if the *same* attachment needs different modes depending on where it sends, since `mode` is a property of the source segment, not of the destination.

### Routing policies do not combine natively with service insertion

[Routing policy rules](./7-routing_policies.md) are not applied in an NFG's route table, so a routing policy cannot filter, summarize, or otherwise act on traffic once it is redirected to a network function group.

The only place where you can combine both is by applying routing policies to the [attachment layer](./9-attachment_routing_policy_rules.md). Any advanced routing need that depends on a policy attaching *after* that point cannot be applied once inspection is in the picture.
