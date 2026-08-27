---
title: "Cloud WAN segment sharing: bidirectional, non-transitive route exchange between segments"
description: "How a share action opens reachability between AWS Cloud WAN segments, why sharing is bidirectional but never transitive, and the three share-with forms including the wildcard and except. Includes how a routing policy applied to a share reads its direction from the segment the share is declared on."
---

# Segment sharing

Segments are closed to one another by default. A [`share`](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html) action opens a path from one segment to one or more others, and it is the simplest way to do it: routes are exchanged so attachments on each side can reach each other, with nothing in the traffic path.

Two properties define how a share behaves, and both differ from what a traditional routed network would give you.

* **A share is bidirectional.** AWS Cloud WAN creates mutual advertisements between the segment and the segments it is shared with, so routes travel both ways from one declaration. There is no one-way export.
* **A share is not transitive.** If `A` shares with `B` and `B` shares with `C`, then `A` and `C` still cannot reach each other. Only routes to a segment's own attachments cross — neither [a static route](./6-static_routes.md) nor [a route learned from another share](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-network-actions-routes.html) travels on.

> **A share is bidirectional, but a routing policy configured on it is not.** Every routing policy is declared `inbound` or `outbound`, so it applies to one direction of the exchange only. Covering both directions means naming a policy for each.

The `segment-actions` array is optional. Every field a `share` entry accepts appears below:

```json
{
  "segment-actions": [
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "shared",
      "share-with": ["production", "development"],
      "routing-policy-names": ["filterRoutesIntoShared"]
    }
  ]
}
```

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `action` | Which segment action this entry is — `share` for sharing | Yes | `share` |
| `mode` | Which routes cross the share — `attachment-route` is the only value | Yes | — |
| `segment` | The segment the share is declared on | Yes | — |
| `share-with` | The segments that gain reachability with `segment` | Yes | — |
| `routing-policy-names` | Routing policies to apply to this share | No | — |

## `segment` and `share-with`

These name the two sides. `segment` is the segment the share is declared on, and `share-with` is what gains reachability with it. Sharing happens between `segment` and each counterpart, never between the counterparts themselves — one action gives `production` and `development` access to `shared` while leaving them unable to reach each other, which is a property of the model rather than something you configured.

`share-with` takes three forms:

| Form | Shares with | Reach for it when |
|------|-------------|-------------------|
| **Array** | Exactly the segments listed | The counterparts are known, and a new segment must not join without a decision |
| **`"*"`** | Every other segment in the core network | Every segment needs this reachability, including ones added later |
| **`except`** | Every other segment bar those listed | The exclusions are fewer than the segments needing reachability |

**Array**

```json
{
  "segment": "shared",
  "share-with": ["production", "development"]
}
```

**`"*"`**

```json
{
  "segment": "hybrid",
  "share-with": "*"
}
```

**`except`**

```json
{
  "segment": "hybrid",
  "share-with": {
    "except": ["sandbox"]
  }
}
```

> **`"*"` and `except` both include segments that do not exist yet.** A segment added next year for a sensitive workload is reachable on day one, without anybody deciding that. Enumerate unless you want that behaviour, and where you use `except`, make the exclusion list part of whatever review adds a segment.

For any given pair of segments, which one goes in which field makes no difference to reachability, since the advertisement is mutual — until a routing policy is involved, when direction is read relative to `segment` (see below for more information).

## `routing-policy-names`

An array of [routing policies](./7-routing_policies.md) to apply to this share, each one named as declared in the `routing-policies` section. Two capabilities come with them. Routes can be **filtered**, so a share opens a path and still carries only part of what each side knows. And their **BGP attributes can be modified** — local preference, MED, AS_PATH, communities — so a share can shape which of several paths wins, not just whether a prefix is known at all.

Routing policies arrived with policy [`version`](./1-core_network_version_configuration.md) `2025.11`, so this field needs a document declaring that version or later.

> **Summarization is not one of them.** It only works outbound and on BGP-capable attachments, because collapsing prefixes into an aggregate happens in an advertisement to a BGP peer — and a share, propagating routes inside the core network, has no peer on the far end.

```json
{
  "action": "share",
  "mode": "attachment-route",
  "segment": "production",
  "share-with": ["hybrid"],
  "routing-policy-names": ["allowOnPremisesCore"]
}
```

Which routes a policy acts on is not stated on the share. It follows from the policy's own `routing-policy-direction`, and that direction is always read **from the point of view of the segment named in `segment`**. Two steps resolve it every time:

1. **Find the reference point.** It is the segment in the `segment` field, never one in `share-with`.
2. **Read the direction from there.** `inbound` acts on routes arriving *at* that segment from the `share-with` side. `outbound` acts on routes leaving it *towards* them.

**Policies on a share are unidirectional**, so one policy governs one of those two flows and leaves the other untouched. All four combinations:

| `segment` | `share-with` | Direction | Acts on routes travelling |
|-----------|--------------|-----------|---------------------------|
| `production` | `["hybrid"]` | `inbound` | `hybrid` → `production` |
| `production` | `["hybrid"]` | `outbound` | `production` → `hybrid` |
| `hybrid` | `["production"]` | `inbound` | `production` → `hybrid` |
| `hybrid` | `["production"]` | `outbound` | `hybrid` → `production` |

Rows one and four act on the same flow, as do rows two and three: swapping the two segments leaves reachability untouched but inverts what every attached policy does. Both spellings deploy cleanly, so pick a convention — one segment always in `segment` — and read directions against it.

> **Filtering routes is not access control.** A policy on a share changes which prefixes each side learns, not what traffic is permitted, and a host with a static route can still send packets at a prefix it was never told about. Where a boundary needs enforcing, put the traffic through [service insertion](./5-service_insertion.md) instead.

Two ordering facts complete the picture:

1. Share policies are applied after attachment policies, so an attachment associates first and only then does sharing decide what it reaches.
2. Segments carry their own [`deny-filter` and `allow-filter`](./2-segments-and-nfg.md#deny-filter-and-allow-filter) guardrails, evaluated after every share — those bound which segments may exchange routes at all, where routing policies work a level down, on the prefixes.
