# Routing policies

A [routing policy](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html) is a named, ordered set of match-action rules that Cloud WAN evaluates as routes propagate through the core network. Rules match on routes and act on routes, never on packets: a policy changes forwarding only by changing the routes the forwarding decision is made from.

> **Routing policies need policy [`version`](./1-core_network_version_configuration.md#version) `2025.11` or later.** They were introduced in that version, together with all three of their association scopes, so a core network policy declaring anything earlier cannot use what is on this page.

Three capabilities, each covered in depth further down:

| Capability | What it does | Where it works |
|---|---|---|
| Filtering | Drops routes, so the receiving side never learns them and cannot reach what they point to | Every scope and every attachment type — the only capability a VPC attachment supports, inbound |
| Summarization | Replaces many specific prefixes with one aggregate advertisement | Outbound, on BGP-capable attachments |
| BGP attribute modification | Rewrites AS_PATH, MED, local preference or communities so the receiver prefers one path over another | BGP-capable attachments, segment shares and edge pairs — individual actions carry further limits |

*BGP-capable* means the attachment has a BGP peer on the far side to advertise to: Site-to-Site VPN, Direct Connect, Connect, or Transit Gateway peering. A VPC attachment has none, which is why filtering is all it supports.

A policy is inert on its own. It lives in the `routing-policies` array and starts acting only once associated, and there are three scopes to associate it with — each configured on its own page:

| Scope | Acts on routes | Configured in |
|---|---|---|
| Attachment | Learned from, or advertised to, one attachment | [`9-attachment_routing_policy_rules.md`](./9-attachment_routing_policy_rules.md) |
| Segment share | Crossing between two shared segments | [`4-segment_sharing.md`](./4-segment_sharing.md#routing-policy-names) |
| Edge location pair | Crossing between two Regions, CNE to CNE | [`8-edge_location_associations.md`](./8-edge_location_associations.md) |

Every association is **unidirectional**: the policy's own `routing-policy-direction` picks one side of the exchange, and routes travelling the other way are untouched. Covering both directions means two policies.

> **Routes propagate unless a rule drops them.** Routing policy rules operate on a default-allow basis — a route that matches no rule, or matches only attribute-modification rules, keeps propagating. Filtering happens only where a `drop` explicitly matches.

## Defining a routing policy

Every field a `routing-policies` entry accepts:

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `routing-policy-name` | The policy's name, and the only way associations refer to it | Yes | — |
| `routing-policy-description` | A free-text description | No | — |
| `routing-policy-direction` | Which side of the route exchange the policy acts on — `inbound` or `outbound` | Yes | — |
| `routing-policy-number` | Priority when several policies land on the same resource — lower runs first | Yes | — |
| `routing-policy-rules` | The ordered match-action rules | Yes | — |

### `routing-policy-name` and `routing-policy-number`

The `routing-policy-name` is the handle every association uses, and has to be unique — alphanumeric only. `routing-policy-number` orders policies that land on the **same resource**: lower runs first. It does not order rules inside a policy, which is `rule-number`'s job.

```json
{
  "routing-policies": [
    {
      "routing-policy-name": "dropTestPrefixes",
      "routing-policy-description": "Test ranges never reach on premises",
      "routing-policy-number": 100,
      "routing-policy-direction": "outbound"
    }
  ]
}
```

### `routing-policy-direction`

Read from the point of view of the resource the policy is associated with:

| Direction | Acts on |
|-----------|---------|
| `inbound` | Routes arriving — learned from an attachment, entering a segment across a share, or arriving at an edge from its peer |
| `outbound` | Routes leaving — advertised to an attachment, leaving a segment across a share, or sent from an edge to its peer |

Both directions describe a route crossing a boundary, and the boundary moves with the scope:

| Scope | The boundary | `inbound` means | `outbound` means | Details |
|---|---|---|---|---|
| Attachment | The core network's edge at that attachment | Coming from the attachment, into the core network | Going from the core network, out to the attachment | [`9-attachment_routing_policy_rules.md`](./9-attachment_routing_policy_rules.md) |
| Segment share | The segment named in `segment` | Entering that segment | Leaving that segment | [`4-segment_sharing.md`](./4-segment_sharing.md#routing-policy-names) |
| Edge location pair | The edge named in `edge-location` | Arriving from `peer-edge-location` | Sent to `peer-edge-location` | [`8-edge_location_associations.md`](./8-edge_location_associations.md) |

### `routing-policy-rules`

The ordered rules. Each rule carries a `rule-number` (lower runs first) and a `rule-definition` with three parts — what to match (`match-conditions`), how to combine the matches (`condition-logic`), and what to do (`action`):

```json
{
  "routing-policy-name": "dropTestPrefixes",
  "routing-policy-description": "Test ranges never reach on premises",
  "routing-policy-number": 100,
  "routing-policy-direction": "outbound",
  "routing-policy-rules": [
    {
      "rule-number": 100,
      "rule-definition": {
        "condition-logic": "or",
        "match-conditions": [
          {
            "type": "prefix-in-cidr",
            "value": "10.100.0.0/16"
          },
          {
            "type": "prefix-equals",
            "value": "10.100.0.0/16"
          }
        ],
        "action": {
          "type": "drop"
        }
      }
    }
  ]
}
```

**`match-conditions`** — what the rule matches on:

| Type | Matches |
|------|---------|
| `prefix-equals` | Exactly this prefix |
| `prefix-in-cidr` | Prefixes contained **within** this CIDR — not the CIDR itself |
| `prefix-in-prefix-list` | Prefixes in a managed prefix list [associated to the core network](../infra/6-prefix_list_association/) |
| `asn-in-as-path` | Routes whose AS_PATH contains this ASN |
| `community-in-list` | Routes carrying this BGP community |
| `med-equals` | Routes with this MED value |

> **`prefix-in-cidr` does not match the prefix itself.** Matching `10.0.0.0/8` catches everything under it but not a literal `10.0.0.0/8` route. To catch both, pair it with `prefix-equals` for the same value.

**`action`** — what happens to a matching route:

| Action | Does | Terminal |
|--------|------|----------|
| `drop` | Removes the route from propagation | **Yes** |
| `allow` | Lets the route through, protecting it from later `drop` rules | **Yes** |
| `summarize` | Replaces matched prefixes with the aggregate in `value` — outbound only | No |
| `prepend-asn-list` | Adds ASNs to the front of AS_PATH, lengthening it | No |
| `remove-asn-list` | Removes ASNs from AS_PATH | No |
| `replace-asn-list` | Replaces ASNs in AS_PATH | No |
| `add-community` | Adds BGP community values | No |
| `remove-community` | Removes BGP community values | No |
| `set-med` | Sets the MED value | No |
| `set-local-preference` | Sets local preference | No |

## How rules are evaluated

Evaluation has three levels: `condition-logic` combines conditions in one rule; rules and policies run in ascending number order. At the rule and policy levels, `drop` and `allow` are terminal:

| Level | Ordered by | Rule |
|---|---|---|
| Conditions in one rule | `condition-logic` | `and` needs every condition to match, `or` needs any one |
| Rules in one policy | `rule-number` | Lower first; `drop` and `allow` are terminal (see the [action table](#routing-policy-rules) above) |
| Policies on one resource | `routing-policy-number` | Lower first; a terminal action in one policy still blocks the next |

> **Rules and policies order the same way, but a policy is reusable and a rule is not.** A rule only exists inside its one policy. A policy has a name and can be associated to several resources at once — so splitting logic into two policies, instead of two rules, is what lets one be reused unchanged elsewhere while the other stays specific to one resource.

### Combining conditions inside a rule

| `condition-logic` | Matches when | Use for |
|---|---|---|
| `and` | Every condition matches | One combined property, e.g. an ASN *and* a community together |
| `or` | Any condition matches | Alternatives, e.g. either of two prefixes |

In this first example, only a route that both passed through ASN `64512` *and* carries community `65051:100` gets the higher preference.

```json
{
  "rule-definition": {
    "match-conditions": [
      {
        "type": "asn-in-as-path",
        "value": 64512
      },
      {
        "type": "community-in-list",
        "value": "65051:100"
      }
    ],
    "condition-logic": "and",
    "action": {
      "type": "set-local-preference",
      "value": 300
    }
  }
}
```

In this second example, a route only ever equals one prefix, never two, so `or` catches either decommissioned range with a single rule.

```json
{
  "rule-definition": {
    "match-conditions": [
      {
        "type": "prefix-equals",
        "value": "192.168.10.0/24"
      },
      {
        "type": "prefix-equals",
        "value": "192.168.20.0/24"
      }
    ],
    "condition-logic": "or",
    "action": { "type": "drop" }
  }
}
```

### Running rules inside one policy

> **Order by terminal action: attribute modifications first, then `allow`, then `drop`.** Put `allow` rules before the `drop` rules they are meant to protect routes from, and put attribute modifications before both — a rule numbered after a terminal match on the same route never runs.

In the following example, rule `50` sets local preference on `10.0.0.0/8` without terminating, so the route carries that preference into rule `100`, which is terminal — evaluation ends there, and rule `200` never sees it. Everything outside `10.0.0.0/8` matches neither `50` nor `100` and reaches `200` unmodified, where it is dropped.

```json
{
  "routing-policy-rules": [
    {
      "rule-number": 50,
      "rule-definition": {
        "match-conditions": [
          {
            "type": "prefix-in-cidr",
            "value": "10.0.0.0/8"
          },
          {
            "type": "prefix-equals",
            "value": "10.0.0.0/8"
          }
        ],
        "condition-logic": "or",
        "action": {
          "type": "set-local-preference",
          "value": 300
        }
      }
    },
    {
      "rule-number": 100,
      "rule-definition": {
        "match-conditions": [
          {
            "type": "prefix-in-cidr",
            "value": "10.0.0.0/8"
          },
          {
            "type": "prefix-equals",
            "value": "10.0.0.0/8"
          }
        ],
        "condition-logic": "or",
        "action": { "type": "allow" }
      }
    },
    {
      "rule-number": 200,
      "rule-definition": {
        "match-conditions": [
          {
            "type": "prefix-in-cidr",
            "value": "0.0.0.0/0"
          },
          {
            "type": "prefix-equals",
            "value": "0.0.0.0/0"
          }
        ],
        "condition-logic": "or",
        "action": { "type": "drop" }
      }
    }
  ]
}
```

### Running multiple policies on the same resource

Every association scope accepts a list of policy names, not just one, ordered by `routing-policy-number`.

The example below shows two routing policies that are meant to be used across multiple Site-to-Site VPN attachments: `filterDecommissionedRoutes` will be associated to all VPN attachments to ensure the decommissioned route is never announced outside the core network, while `preferBranchA` is specific to one or a set of VPN attachments and raises local preference so its routes win over other connections.

> **For how a policy actually gets associated to an attachment**, see [`9-attachment_routing_policy_rules.md`](./9-attachment_routing_policy_rules.md).

```json
{
  "routing-policies": [
    {
      "routing-policy-name": "filterDecommissionedRoutes",
      "routing-policy-number": 100,
      "routing-policy-direction": "inbound",
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              {
                "type": "prefix-equals",
                "value": "192.168.10.0/24"
              }
            ],
            "condition-logic": "or",
            "action": { "type": "drop" }
          }
        }
      ]
    },
    {
      "routing-policy-name": "preferBranchA",
      "routing-policy-number": 200,
      "routing-policy-direction": "inbound",
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              {
                "type": "prefix-in-cidr",
                "value": "0.0.0.0/0"
              },
              {
                "type": "prefix-equals",
                "value": "0.0.0.0/0"
              }
            ],
            "condition-logic": "or",
            "action": { "type": "set-local-preference", "value": 300 }
          }
        }
      ]
    }
  ]
}
```

In the VPN attachment where we have associated both routing policies, `filterDecommissionedRoutes` at `100` runs first, so `preferBranchA` at `200` only ever sees what survived the filter — the decommissioned range is dropped before the preference bump is applied to what remains. Numbered the other way, the preference would be set on routes that were about to be dropped anyway.

> **`routing-policy-number` only orders policies at the same scope.** A route learned through an attachment and then shared into another segment passes two different scopes, in a fixed sequence that `routing-policy-number` does not touch: the [attachment's own policies](./9-attachment_routing_policy_rules.md) run first, then the [share's](./4-segment_sharing.md#routing-policy-names) or [edge association's](./8-edge_location_associations.md).

## Routing policies in practice

### Summarizing routes toward on-premises

Aggregates many specific prefixes into one summary advertisement, keeping on-premises routing tables small. Outbound only, and only on BGP-capable attachments. `summarize` does not care how the prefixes it replaces were matched — this example shows two ways to select them in one rule.

This example combines a literal CIDR and a managed [prefix list](../infra/6-prefix_list_association/) referenced by alias in rule `100`, then adds the two rules that make "on-premises receives the summary and nothing else" actually hold.

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
              {
                "type": "prefix-in-cidr",
                "value": "10.20.0.0/16"
              },
              {
                "type": "prefix-equals",
                "value": "10.20.0.0/16"
              },
              {
                "type": "prefix-in-prefix-list",
                "value": "nvirginiaipv4routes"
              }
            ],
            "condition-logic": "or",
            "action": {
              "type": "summarize",
              "value": "10.0.0.0/8"
            }
          }
        },
        {
          "rule-number": 200,
          "rule-definition": {
            "match-conditions": [
              {
                "type": "prefix-equals",
                "value": "10.0.0.0/8"
              }
            ],
            "condition-logic": "or",
            "action": { "type": "allow" }
          }
        },
        {
          "rule-number": 300,
          "rule-definition": {
            "match-conditions": [
              {
                "type": "prefix-in-cidr",
                "value": "0.0.0.0/0"
              },
              {
                "type": "prefix-equals",
                "value": "0.0.0.0/0"
              }
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

In rule `100`, the paired CIDR conditions select the literal `10.20.0.0/16` route and more-specific prefixes under it, with no separate resource to manage. `prefix-in-prefix-list` selects routes from the managed list by alias — useful when the ranges to summarize are maintained outside the policy or are not consecutive. With `or`, a route matching either selection is summarized into `10.0.0.0/8`.

Rules `200` and `300` are what restrict the advertisement to the summary. Rule `300` drops everything, so anything rule `100` did not summarize is withdrawn; rule `200` sits above it and lets the `10.0.0.0/8` aggregate through. Because `summarize` is **not terminal**, the aggregate rule `100` produced keeps being evaluated — rule `200` is the rule that stops rule `300` from taking it.

> **Omit rule `200` and this policy advertises nothing at all.** `summarize` is non-terminal, so the aggregate it produces carries on down the rules and a catch-all `drop` below it matches and removes it. The prefixes are withdrawn, the summary is dropped, and the peer receives an empty advertisement — with nothing rejected at policy-validation time and no error anywhere to explain it. Whenever a `summarize` and a catch-all `drop` are in the same policy, the `allow` between them is mandatory. The general form of this rule, covering the BGP attribute actions too, is in [Running rules inside one policy](#running-rules-inside-one-policy).

This is commonly associated at the attachment scope — see [`9-attachment_routing_policy_rules.md`](./9-attachment_routing_policy_rules.md) for how. On a Direct Connect gateway the shape above is needed once per Region, scoped with `edge-locations`, for the reason immediately below.

#### Direct Connect gateway needs one summary per Region

A Direct Connect gateway attaches to every CNE. If every CNE advertises the same `10.0.0.0/8`, on-premises routers see equal-cost paths; traffic for a `eu-west-1` workload can enter through `us-east-1` and cross the backbone.

Create one summarization policy per Region's supernet — for example, `summarizeNVirginiaIpv4Routes` for `10.10.0.0/16` and `summarizeIrelandIpv4Routes` for `10.0.0.0/16` — and scope each policy to its Region with [`edge-locations`](./9-attachment_routing_policy_rules.md#edge-locations). Each CNE then advertises only its Region's space, so on-premises traffic enters through the nearest Region.

### Preferring one Region's hybrid edge

When a CNE receives the same on-premises prefix from hybrid attachments in multiple Regions, `prepend-asn-list` can make one inter-Region copy less preferred without removing it as failover.

In this example, hybrid attachments in `us-east-1` and `eu-west-1` advertise the same on-premises prefix. Workloads connected to `eu-south-2` should prefer the path through `eu-west-1`; this policy lengthens the alternative copy propagated from `us-east-1` toward `eu-south-2`:

```json
{
  "routing-policies": [
    {
      "routing-policy-name": "depreferUsEastHybridRoutes",
      "routing-policy-direction": "outbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              {
                "type": "asn-in-as-path",
                "value": 65052
              }
            ],
            "condition-logic": "or",
            "action": {
              "type": "prepend-asn-list",
              "value": [65500, 65501]
            }
          }
        }
      ]
    }
  ]
}
```

`asn-in-as-path` selects routes whose AS_PATH contains `65052` — here, the routes learned through the `us-east-1` hybrid attachment. `prepend-asn-list` lengthens only the copy sent toward `eu-south-2`, so it prefers the equivalent path through `eu-west-1`. Nothing is dropped: the `us-east-1` path remains available as failover.

> The prepended ASNs must not overlap the core network's [`asn-ranges`](./1-core_network_version_configuration.md#asn-ranges).

**For edge-pair association details**, see [`8-edge_location_associations.md`](./8-edge_location_associations.md). The same policy shape can also be applied on a [segment share](./4-segment_sharing.md#routing-policy-names).

### Filtering routes by BGP community

In hybrid environments, an on-premises router can advertise routes for several routing domains through one BGP peer and tag each set with a BGP community. Routing policies expose each tagged set only to its intended segment, reducing the need for separate BGP peers solely to preserve route segmentation.

> **Direct Connect cannot use this pattern.** A Direct Connect gateway strips BGP communities between the virtual interface and the core network, so those tags cannot drive Cloud WAN routing policies.

In this example, the on-premises router advertises test and development routes through one BGP peer. Routes tagged `65051:100` belong to the test domain. This policy admits those routes, then drops every untagged or differently tagged route:

```json
{
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
            "match-conditions": [
              {
                "type": "community-in-list",
                "value": "65051:100"
              }
            ],
            "condition-logic": "or",
            "action": { "type": "allow" }
          }
        },
        {
          "rule-number": 200,
          "rule-definition": {
            "match-conditions": [
              {
                "type": "prefix-in-cidr",
                "value": "0.0.0.0/0"
              },
              {
                "type": "prefix-equals",
                "value": "0.0.0.0/0"
              }
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

Rule `100` allows only routes carrying `65051:100`; the catch-all `drop` in rule `200` keeps every other route out of the test segment. A matching development policy can allow `65051:200` instead. See [`4-segment_sharing.md`](./4-segment_sharing.md#routing-policy-names) for where to apply the policies.

The on-premises router applies the communities before advertising the routes:

```
! On-premises router
route-map TEST-ROUTES permit 10
 match ip address prefix-list TEST-PREFIXES
 set community 65051:100

route-map DEV-ROUTES permit 10
 match ip address prefix-list DEV-PREFIXES
 set community 65051:200
```

## Constraints and workarounds

### Verify policy effects with the right API

**`list-core-network-routing-information` shows routing state *before* routing policies are applied. Do not use it to verify a filter's post-policy result.** For post-policy state, use `get-network-routes` or the route view in the Network Manager console:

```bash
aws networkmanager get-network-routes \
  --global-network-id <global-network-id> \
  --route-table-identifier '{"CoreNetworkSegmentEdge":{"CoreNetworkId":"<id>","SegmentName":"production","EdgeLocation":"us-east-1"}}'
```

`list-core-network-routing-information` remains the right tool for inspecting BGP sessions and pre-policy AS_PATH.

### Routing policies do not apply in service insertion

Routing policies are not supported for a network function group (NFG). When [service insertion](./5-service_insertion.md) redirects traffic to an inspection appliance, policies cannot filter, summarize, or modify BGP attributes in the NFG route table.

Apply any required routing policy at the [attachment layer](./9-attachment_routing_policy_rules.md) before the route enters the service-insertion path.

### TGW route table attachments on one peering share outbound policies

Transit Gateway route table attachments that use the same peering and the same segment share their outbound routing policies: associate policy A to one attachment and policy B to another, and both attachments get both policies. Segment them apart, or across separate peerings, where their outbound treatment must differ.
