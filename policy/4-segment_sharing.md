# Segment Sharing

Produces **`segment-actions`** entries with `action: share` — exchanging routes between
segments **without** inspection.

Segments do not talk to each other by default. Sharing is how you open a path, and it is
the simplest of the three `segment-actions`. Its one surprising property is that it is
**not transitive**, which is worth understanding before you draw a topology.

```json
{
  "segment-actions": [
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "shared",
      "share-with": ["production", "development"]
    }
  ]
}
```

That says: *routes in `shared` are visible to `production` and `development`, and their
routes are visible to `shared`.* Sharing exchanges routes in both directions between the
named segments — it is a mutual relationship, not a one-way export.

## `mode: attachment-route`

The only mode in practical use. Routes learned from the segment's attachments are
exchanged with the segments named in `share-with`.

## `share-with: "*"`

You can share with every other segment:

```json
{
  "segment-actions": [
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "hybrid",
      "share-with": "*"
    }
  ]
}
```

This is genuinely useful for a `hybrid` segment — on-premises usually needs to reach
everything, and enumerating every workload segment means editing the policy each time a
new one appears.

Be deliberate about it elsewhere. `"*"` means *future* segments are included too, so a
segment added next year for a sensitive workload is reachable from this one on day one
without anybody deciding that. For anything other than the hybrid case, enumerate.

## Non-transitivity, and why it is a feature

**If `A` shares with `B`, and `B` shares with `C`, then `A` and `C` are not connected.**

```json
{
  "segment-actions": [
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "shared",
      "share-with": ["production"]
    },
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "shared",
      "share-with": ["development"]
    }
  ]
}
```

`production` reaches `shared`. `development` reaches `shared`. `production` and
`development` **cannot reach each other** — and there is no accidental path through the
shared segment.

In a traditional routed network, connecting a hub to two spokes usually gives you
spoke-to-spoke reachability as a side effect, and you then filter it back out. Cloud WAN
inverts the default: nothing is reachable until declared, and no relationship you did not
write can appear.

The practical method: **draw the graph, then write one `share` action per edge.** If you
find yourself assuming a path exists because two segments both connect to a third, you
have found a bug in the design rather than a Cloud WAN limitation.

## The shared-services pattern

The most common real use, and what [`infra/1-basic`](../infra/1-basic/) deploys:

```json
{
  "segments": [
    { "name": "production", "require-attachment-acceptance": false },
    { "name": "development", "require-attachment-acceptance": false },
    { "name": "shared", "require-attachment-acceptance": false, "isolate-attachments": true }
  ],
  "segment-actions": [
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "shared",
      "share-with": ["production", "development"]
    }
  ]
}
```

Three properties combine here, and each comes from a different place:

| Property | Comes from |
|----------|------------|
| Workloads reach shared services | The `share` action |
| Workload segments cannot reach each other | Non-transitivity — nothing to configure |
| Shared services cannot reach each other | `isolate-attachments: true` on `shared` |

The resulting reachability:

| Source | Destination | Result |
|--------|-------------|--------|
| `production` | `shared` | ✅ Allowed |
| `development` | `shared` | ✅ Allowed |
| `production` | `production` (other Region) | ✅ Allowed — same segment, not isolated |
| `production` | `development` | ❌ Blocked — no share declared |
| `shared` | `shared` (other attachment) | ❌ Blocked — segment is isolated |

That last row is worth dwelling on: a shared-services VPC hosting a directory service
and another hosting a logging pipeline can both be reached by workloads, while remaining
unable to reach each other. Achieving that with route tables is fiddly; here it is one
boolean.

## Filtering while sharing

A `share` action can carry routing policies, so only some routes cross the boundary:

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

This is how you build a single hybrid segment that presents a *different* view of
on-premises to each workload segment — development sees only development prefixes, test
sees only test prefixes, from one BGP session. The routing policy that does the filtering
is defined in [`6-routing_policies.md`](./6-routing_policies.md).

Two constraints:

- **Routing policies on a share are unidirectional.** The policy applies in one
  direction; if you need filtering both ways, declare both.
- **Share policies are applied after attachment policies.** Attachments associate first,
  then sharing determines reachability.

## Sharing versus service insertion

Both connect segments. The difference is whether traffic is inspected:

| | `share` | `send-via` |
|---|---|---|
| Traffic path | Direct between attachments | Through a network function group |
| Use when | The segments are mutually trusted | Traffic must be inspected or logged |
| Cost | No additional data path | Inspection VPC + appliance per Region |
| Latency | Direct | Extra hop, or two in dual-hop mode |

If a boundary needs a firewall, use [`5-service_insertion.md`](./5-service_insertion.md)
instead. Do not use `share` and expect to filter with a routing policy — route filtering
controls *which prefixes are known*, not *what the traffic is allowed to do*. Dropping a
route is not a security control; a host with a static route can still send packets.

## Constraints to carry forward

| Constraint | Consequence |
|------------|-------------|
| Sharing is **non-transitive** | Declare every relationship explicitly |
| Sharing is mutual between the named segments | Not a one-way export |
| `share-with: "*"` includes segments added later | Enumerate unless you want that |
| Routing policies on a share are **unidirectional** | Declare both directions if needed |
| Share actions apply **after** attachment policies | Association first, reachability second |
| Route filtering is not access control | Use service insertion for enforcement |

## Next

[`5-service_insertion.md`](./5-service_insertion.md) — connecting segments *through* an
inspection appliance.

## Reference

- [Core network policy parameters](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html)
