# Routing Policies

Produces **`routing-policies`** and **`attachment-routing-policy-rules`** — BGP-level
control over which routes propagate, how they are aggregated, and which paths are
preferred.

This is the sharpest tool in Cloud WAN. Everything before this page decides *what is
connected*; this page decides *what each part of the network knows*. It is also the
easiest section to get subtly wrong, because a misordered rule produces a policy that
deploys cleanly and silently drops everything.

Requires policy `version: 2025.11` — see
[`1-core_network_configuration.md`](./1-core_network_configuration.md).

## The three things you must decide

Every routing policy answers three questions. Get them in this order:

1. **Where does it attach?** Attachments, a segment share, or a CNE-to-CNE pair.
2. **Which direction?** `inbound` or `outbound`.
3. **What does it do?** Filter, summarize, or modify BGP attributes.

## 1. Where a policy attaches

### To attachments, via a routing-policy label

Two steps: define the policy, then bind it to attachments carrying a label.

```json
{
  "attachment-routing-policy-rules": [
    {
      "rule-number": 100,
      "conditions": [
        { "type": "routing-policy-label", "value": "vpcAttachments" }
      ],
      "action": { "associate-routing-policies": ["secondaryCidrFiltering"] }
    }
  ]
}
```

The label is applied to the attachment itself (after deployment, or by your IaC). This is
the indirection that keeps the policy independent of any specific attachment ID.

### To a segment share

The policy applies to routes crossing between two segments:

```json
{
  "segment-actions": [
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "hybrid",
      "share-with": ["development"],
      "routing-policy-names": ["filterDevelopmentRoutes"]
    }
  ]
}
```

### To a CNE-to-CNE (edge location) pair

The policy applies to routes crossing between two Regions:

```json
{
  "segment-actions": [
    {
      "action": "associate-routing-policy",
      "segment": "vpcs",
      "edge-location-association": {
        "routing-policy-names": ["addASPath"],
        "edge-location": "us-east-1",
        "peer-edge-location": "eu-west-1"
      }
    }
  ]
}
```

This is how you influence *inter-Region* path selection without touching any attachment.

> **All three scopes are unidirectional.** A policy on the `us-east-1` → `eu-west-1`
> direction does nothing to routes travelling the other way. If you need symmetry,
> declare both.

## 2. Direction

| Direction | Applies to |
|-----------|-----------|
| `inbound` | Routes entering Cloud WAN (learned *from* an attachment, or arriving from a peer edge) |
| `outbound` | Routes leaving Cloud WAN (advertised *to* an attachment, or sent to a peer edge) |

Two facts that constrain the choice:

- **VPC attachments only support `inbound`.** A VPC attachment cannot have BGP attributes
  modified — it is effectively inbound-filter-only (`cwan-12`).
- **Summarization only works `outbound`**, and only on BGP-capable attachments
  (`cwan-10`).

## 3. Rule ordering — the mistake to avoid

Rules within a policy are numbered and evaluated in order. The idiomatic shape for an
allow-list is **allow what you want at a low number, then a catch-all drop**:

```json
{
  "routing-policies": [
    {
      "routing-policy-name": "allowCidrRange",
      "routing-policy-description": "Allow 10.0.0.0/8, drop everything else",
      "routing-policy-direction": "inbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              { "type": "prefix-in-cidr", "value": "10.0.0.0/8" }
            ],
            "condition-logic": "or",
            "action": { "type": "allow" }
          }
        },
        {
          "rule-number": 200,
          "rule-definition": {
            "match-conditions": [
              { "type": "prefix-in-cidr", "value": "0.0.0.0/0" },
              { "type": "prefix-equals", "value": "0.0.0.0/0" }
            ],
            "condition-logic": "or",
            "action": { "type": "drop" }
          }
        }
      ]
    }
  ]
}
```

Reverse those rule numbers and the policy drops every route, including the ones rule 100
was supposed to allow — and it deploys without complaint. `tools/validate_policy.py`
treats an `allow` placed after a catch-all `drop` as an **error** (`cwan-3`).

Note the pairing of `prefix-in-cidr` with `prefix-equals` in the catch-all. `prefix-in-cidr`
matches prefixes *contained within* the CIDR; `prefix-equals` matches the CIDR itself. Both
are needed to catch a literal default route as well as everything under it.

## Match conditions

| Type | Matches |
|------|---------|
| `prefix-equals` | Exactly this prefix |
| `prefix-in-cidr` | Any prefix contained within this CIDR |
| `prefix-in-prefix-list` | Any prefix in a managed prefix list, by alias |
| `community-in-list` | Routes carrying a BGP community |
| `asn-in-as-path` | Routes whose AS_PATH contains an ASN |

## Route filtering

### Dropping a specific prefix

The classic case: a VPC has a secondary CIDR for internal-only traffic — Kubernetes pod
networks, cluster communication — that should not propagate across the network.

![Filtering secondary CIDR blocks](../images/patterns_filtering_secondary_cidr_blocks.png)

```json
{
  "routing-policies": [
    {
      "routing-policy-name": "secondaryCidrFiltering",
      "routing-policy-description": "Drop internal-only secondary VPC CIDR blocks",
      "routing-policy-direction": "inbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              { "type": "prefix-equals", "value": "10.100.0.0/16" }
            ],
            "condition-logic": "or",
            "action": { "type": "drop" }
          }
        }
      ]
    }
  ]
}
```

`inbound` because it is applied at the VPC attachment, and VPC attachments only support
inbound. Bind it with a `vpcAttachments` label as shown above.

### Protocol-specific segments

Filtering while sharing lets you build IPv4-only and IPv6-only segments from dual-stack
sources — useful for legacy IPv4 systems or IPv6-only workloads that must not learn the
other family.

```json
{
  "segment-actions": [
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "ipv4only",
      "share-with": ["production", "development"],
      "routing-policy-names": ["filterIpv6"]
    },
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "ipv6only",
      "share-with": ["production", "development"],
      "routing-policy-names": ["filterIpv4"]
    }
  ],
  "routing-policies": [
    {
      "routing-policy-name": "filterIpv4",
      "routing-policy-description": "Filter all IPv4 ranges",
      "routing-policy-direction": "inbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              { "type": "prefix-in-cidr", "value": "0.0.0.0/0" },
              { "type": "prefix-equals", "value": "0.0.0.0/0" }
            ],
            "condition-logic": "or",
            "action": { "type": "drop" }
          }
        }
      ]
    },
    {
      "routing-policy-name": "filterIpv6",
      "routing-policy-description": "Filter all IPv6 ranges",
      "routing-policy-direction": "inbound",
      "routing-policy-number": 200,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              { "type": "prefix-in-cidr", "value": "::/0" },
              { "type": "prefix-equals", "value": "::/0" }
            ],
            "condition-logic": "or",
            "action": { "type": "drop" }
          }
        }
      ]
    }
  ]
}
```

The same technique filters a peered Transit Gateway — apply `filterIpv4` to a
`tgwAttachment` label to allow only IPv6 between Regions through the TGW peering, which is
a useful stepping stone during a migration.

### Filtering before inspection

**Routing policies cannot attach to a network function group.** When you need both
filtering and inspection, filter at the attachment layer first; the surviving routes are
then subject to the `send-via` action.

```json
{
  "attachment-routing-policy-rules": [
    {
      "rule-number": 100,
      "conditions": [
        { "type": "routing-policy-label", "value": "vpcAttachments" }
      ],
      "action": { "associate-routing-policies": ["allowCidrRange"] }
    }
  ],
  "segment-actions": [
    {
      "action": "send-via",
      "segment": "production",
      "mode": "dual-hop",
      "when-sent-to": { "segments": ["development"] },
      "via": { "network-function-groups": ["inspectionVpcs"] }
    }
  ]
}
```

Secondary CIDRs never enter the segment, so they are never inspected and never routed —
while primary CIDRs are both. See [`5-service_insertion.md`](./5-service_insertion.md)
and `cwan-7`.

## Route summarization

Aggregates many specific routes into one summary before advertising them, which keeps
on-premises routing tables small.

![Route summarization](../images/patterns_summarization.png)

**`outbound` only, and only on BGP-capable attachments** — Site-to-Site VPN, Connect,
Direct Connect gateway, Transit Gateway peering, CNE-to-CNE. It has no effect on a VPC
attachment.

```json
{
  "routing-policies": [
    {
      "routing-policy-name": "summarizeIpv4Routes",
      "routing-policy-direction": "outbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              { "type": "prefix-in-prefix-list", "value": "nvirginiaipv4routes" },
              { "type": "prefix-in-prefix-list", "value": "irelandipv4routes" }
            ],
            "condition-logic": "or",
            "action": { "type": "summarize", "value": "10.0.0.0/8" }
          }
        }
      ]
    }
  ]
}
```

Matching uses **managed prefix lists** by alias. Those prefix lists must be created in
`us-west-2` — Cloud WAN's home Region — regardless of where your edge locations are, and
associated with the core network (`cwan-13`).

### Why Direct Connect gateway needs per-Region summaries

This is the non-obvious part, and getting it wrong causes cross-Region traffic you did not
ask for.

- **VPN and Connect attach to a single CNE.** All AWS routes can be safely summarized into
  one supernet — there is only one entry point, so there is no ambiguity.
- **A Direct Connect gateway attaches to every CNE.** If each CNE advertised the same
  `10.0.0.0/8`, on-premises routers would see equal-cost paths to every Region and could
  send traffic into any of them — so a packet for a `eu-west-1` workload might enter via
  `us-east-1` and cross the backbone.

The fix is a per-Region supernet, so each CNE advertises only its own Region's space and
on-premises always enters through the nearest CNE:

```json
{
  "attachment-routing-policy-rules": [
    {
      "rule-number": 100,
      "conditions": [{ "type": "routing-policy-label", "value": "vpnAttachment" }],
      "action": { "associate-routing-policies": ["summarizeIpv4Routes"] }
    },
    {
      "rule-number": 200,
      "conditions": [{ "type": "routing-policy-label", "value": "dxAttachment" }],
      "action": {
        "associate-routing-policies": [
          "summarizeNVirginiaIpv4Routes",
          "summarizeIrelandIpv4Routes"
        ]
      }
    }
  ]
}
```

Where `summarizeNVirginiaIpv4Routes` summarizes to `10.10.0.0/16` and
`summarizeIrelandIpv4Routes` to `10.0.0.0/16`.

> Summarization **withdraws** the matched specific prefixes and advertises the summary.
> The withdrawal and the advertisement happen together, but make sure your summary
> actually covers every prefix it replaces — a gap becomes an unreachable range.

## Path preferences

Modify BGP attributes to influence which path is chosen when several advertise the same
prefix. Actions: `prepend-asn-list`, `replace-asn`, `remove-asn`,
`set-local-preference`, `set-med`.

### Preferring one Region's hybrid edge

Two hybrid connections in different Regions advertise the same on-premises prefix, and you
want one Region's VPCs to prefer the other Region's edge. Make the path via `us-east-1`
less attractive by lengthening its AS_PATH on the CNE-to-CNE peering:

```json
{
  "segment-actions": [
    {
      "action": "associate-routing-policy",
      "segment": "vpcs",
      "edge-location-association": {
        "routing-policy-names": ["addASPath"],
        "edge-location": "us-east-1",
        "peer-edge-location": "eu-west-1"
      }
    }
  ],
  "routing-policies": [
    {
      "routing-policy-name": "addASPath",
      "routing-policy-direction": "outbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              { "type": "asn-in-as-path", "value": 65052 }
            ],
            "condition-logic": "or",
            "action": { "type": "prepend-asn-list", "value": [65500, 65501] }
          }
        }
      ]
    }
  ]
}
```

Only routes that came from ASN `65052` — the `us-east-1` on-premises router — are
lengthened, so unrelated routes are unaffected. The prepended ASNs (`65500`, `65501`) must
sit **outside** the core network's `asn-ranges` (`cwan-6`).

### Preferring the geographically aligned Direct Connect gateway

![Influencing the Direct Connect gateway path](../images/patterns_influencing_dxgw_hybrid_path.png)

Two Direct Connect gateways, both attached to all CNEs, both advertising the same
on-premises prefix. European VPCs should prefer the Europe DXGW and US VPCs the US DXGW.
Apply a different policy to each segment share:

```json
{
  "segment-actions": [
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "hybrid",
      "share-with": ["europevpcs"],
      "routing-policy-names": ["addASPathUS"]
    },
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "hybrid",
      "share-with": ["usvpcs"],
      "routing-policy-names": ["addASPathEurope"]
    }
  ],
  "routing-policies": [
    {
      "routing-policy-name": "addASPathEurope",
      "routing-policy-description": "Make the Europe DXGW less preferred",
      "routing-policy-direction": "outbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [{ "type": "asn-in-as-path", "value": 64512 }],
            "condition-logic": "or",
            "action": { "type": "prepend-asn-list", "value": [65500, 65501] }
          }
        }
      ]
    },
    {
      "routing-policy-name": "addASPathUS",
      "routing-policy-description": "Make the US DXGW less preferred",
      "routing-policy-direction": "outbound",
      "routing-policy-number": 200,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [{ "type": "asn-in-as-path", "value": 64513 }],
            "condition-logic": "or",
            "action": { "type": "prepend-asn-list", "value": [65500, 65501] }
          }
        }
      ]
    }
  ]
}
```

Each segment is told to *deprefer the far gateway*, so it prefers the near one. The other
path remains available as failover — which is the point, and is what you lose if you solve
this by filtering instead.

## BGP communities

Communities are matched, set, and propagated transitively. The high-value use is carrying
several routing domains over a **single** BGP session.

![Filtering by BGP community](../images/patterns_filtering_bgp_community.png)

Before this, keeping on-premises development and test traffic separate meant one BGP
session per domain. Now the on-premises router tags routes with a community and Cloud WAN
sorts them into segments:

```json
{
  "segment-actions": [
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "hybrid",
      "share-with": ["test"],
      "routing-policy-names": ["filterTestRoutes"]
    },
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "hybrid",
      "share-with": ["development"],
      "routing-policy-names": ["filterDevelopmentRoutes"]
    }
  ],
  "routing-policies": [
    {
      "routing-policy-name": "filterTestRoutes",
      "routing-policy-description": "Allow only routes tagged 65051:100 (test)",
      "routing-policy-direction": "outbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [{ "type": "community-in-list", "value": "65051:100" }],
            "condition-logic": "or",
            "action": { "type": "allow" }
          }
        },
        {
          "rule-number": 200,
          "rule-definition": {
            "match-conditions": [
              { "type": "prefix-in-cidr", "value": "0.0.0.0/0" },
              { "type": "prefix-equals", "value": "0.0.0.0/0" }
            ],
            "condition-logic": "or",
            "action": { "type": "drop" }
          }
        }
      ]
    }
  ]
}
```

The corresponding on-premises configuration:

```
! On-premises router
route-map TEST-ROUTES permit 10
 match ip address prefix-list TEST-PREFIXES
 set community 65051:100

route-map DEV-ROUTES permit 10
 match ip address prefix-list DEV-PREFIXES
 set community 65051:200
```

**Communities are not supported on Direct Connect gateway or Transit Gateway peering
attachments** (`cwan-11`). This pattern needs Site-to-Site VPN or Connect — see
[`infra/4-hybrid`](../infra/4-hybrid/).

Also note that external devices cannot advertise communities containing ASNs the core
network is already using.

## Verifying a routing policy took effect

There is a trap here worth knowing:

> **`list-core-network-routing-information` shows routing state BEFORE routing policies
> are applied.** Do not use it to prove a filter worked — it will show you the routes you
> think you dropped.

Use `get-network-routes`, or the route view in the Network Manager console, for the
post-policy state:

```bash
aws networkmanager get-network-routes \
  --global-network-id <global-network-id> \
  --route-table-identifier '{"CoreNetworkSegmentEdge":{"CoreNetworkId":"<id>","SegmentName":"production","EdgeLocation":"us-east-1"}}'
```

`list-core-network-routing-information` remains the right tool for inspecting BGP sessions
and pre-policy AS_PATH.

## Constraints to carry forward

Nearly every item here is a real limitation that will bite:

| Constraint | Check |
|------------|-------|
| **Not supported for network function groups** — filter at the attachment layer instead | `cwan-7` |
| **VPC attachments cannot modify BGP attributes** — inbound filtering only | `cwan-12` |
| **Summarization is outbound only**, and only on BGP-capable attachments | `cwan-10` |
| **No BGP communities on Direct Connect gateway or TGW peering** | `cwan-11` |
| Policies across segments and Regions are **unidirectional** | — |
| Routing-policy ASNs must not overlap the core `asn-ranges` | `cwan-6` |
| **Replace-ASN is not supported cross-Region** (CNE-to-CNE) | — |
| Prefix lists must be created in `us-west-2` and aliases must be unique per association | `cwan-13` |
| `allow` rules must precede a catch-all `drop` | `cwan-3` |
| Routing-policy numbers and rule numbers must be unique | `cwan-3`, `cwan-5` |
| External devices cannot advertise communities containing core-network ASNs | — |
| TGW route-table attachments sharing a peering and segment **share outbound policies** | — |
| `list-core-network-routing-information` shows **pre-policy** state | — |

## Next

You have now covered the whole policy document. To assemble one for a real requirement,
see [`policy_generator.md`](./policy_generator.md).

## Reference

- [Routing policies, incl. key considerations](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html)
- [Create a routing policy and rule](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-route-policy.html)
- [Example routing-policy document](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-examples-routing-policies.html)
- [Routing Policy deep dive (part 1)](https://aws.amazon.com/blogs/networking-and-content-delivery/aws-cloud-wan-routing-policy-fine-grained-controls-for-your-global-network-part-1/)
