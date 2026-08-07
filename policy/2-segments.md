# Segments

Produces the **`segments`** array. A segment is a **global routing domain** — one route
table replicated across every Region that has a Core Network Edge.

This is the most important concept in Cloud WAN, and the biggest departure from Transit
Gateway. With Transit Gateway you have a route table *per Region* and you keep them
consistent yourself. With Cloud WAN you declare a segment once and it exists everywhere,
with cross-Region reachability inside it handled by the CNE mesh.

```json
{
  "segments": [
    { "name": "production", "require-attachment-acceptance": false },
    { "name": "development", "require-attachment-acceptance": false },
    { "name": "shared", "require-attachment-acceptance": false, "isolate-attachments": true }
  ]
}
```

That is a complete, working segment definition. Three routing domains, in every Region
you declared edge locations for, with no route tables to reconcile.

## Why "global" is the point

Declare `production` with edges in `us-east-1` and `eu-west-1`, and:

- A VPC attached to `production` in `us-east-1` reaches a VPC attached to `production`
  in `eu-west-1`. No peering, no static route, no propagation to configure.
- Adding `ap-southeast-2` as an edge location extends `production` there automatically.
  Attachments created in the new Region pick up the existing attachment policies.
- Prefixes propagate into the segment automatically as attachments are created.

The mental model to carry: **a segment is a VRF that happens to span the planet.** What
you spend your time on is deciding which VRFs exist and which ones may talk to each
other — not on plumbing.

## Choosing a segmentation axis

Segments are routing domains, so segment on the boundary you want to *control traffic
across*. The three that work in practice:

| Axis | Segments | Use when |
|------|----------|----------|
| **Environment** | `production`, `development`, `test` | Isolation between lifecycle stages is the primary control |
| **Business unit** | `orga`, `orgb`, `shared` | Different teams or tenants must not reach each other by default |
| **Geography** | `amer`, `emea`, `apac` | Data residency or regional autonomy drives the design |

You can combine them (`prod-emea`), but the count multiplies fast — be sure the extra
boundary is one you will actually enforce.

**One segment per application is an anti-pattern.** Segments are a routing construct
with a per-core-network quota, not an application grouping. If you want per-application
control, that is a security-group or a VPC Lattice problem, not a segment problem. A
useful test: if two things would always be shared with exactly the same set of other
segments, they belong in one segment.

## `isolate-attachments`

Blocks traffic *between attachments within the same segment*. It has two distinct uses,
and conflating them causes real confusion.

```json
{
  "name": "shared",
  "require-attachment-acceptance": false,
  "isolate-attachments": true
}
```

### Use 1 — hub-and-spoke inside one segment

Attachments can reach whatever the segment is *shared with*, but not each other. This is
what makes a shared-services segment work: every workload segment reaches shared
services, and the shared services do not reach one another.

[`infra/1-basic`](../infra/1-basic/)'s baseline policy uses exactly this: `shared` is
isolated and shared with `production` and `development`.

### Use 2 — the prerequisite for inspecting intra-segment traffic

This one is not obvious and it is the more common source of failure.

If you want traffic between two attachments **in the same segment** to pass through a
firewall, the segment **must** be isolated. Without isolation, Cloud WAN has a direct
route between those attachments and will use it — the traffic never reaches the
inspection path, and your `send-via` action appears to do nothing.

Isolation is what removes the direct route so the only path is via the network function
group.

```json
{
  "segments": [
    {
      "name": "production",
      "require-attachment-acceptance": false,
      "isolate-attachments": true
    }
  ],
  "segment-actions": [
    {
      "action": "send-via",
      "segment": "production",
      "mode": "dual-hop",
      "when-sent-to": { "segments": "*" },
      "via": { "network-function-groups": ["inspectionVpcs"] }
    }
  ]
}
```

`tools/validate_policy.py` flags this as an error (`cwan-8`) because a policy that looks
like inspection but silently bypasses it is worse than one that fails to deploy. See
[`5-service_insertion.md`](./5-service_insertion.md).

## `require-attachment-acceptance`

Whether a new attachment must be **manually approved** before it joins the segment. A
pending attachment cannot reach the core network.

```json
{
  "name": "production",
  "require-attachment-acceptance": true
}
```

In a single account this is mostly ceremony — you created the attachment, you know it
should be there. Every pattern in this repository sets it to `false` so demos deploy
without a manual step.

**Across accounts it is a real control.** In a shared core network the attachment is
created by another team, and the tag that decides its segment is set by that team (see
[`3-attachment_policies.md`](./3-attachment_policies.md)). Acceptance is what stops a
spoke account placing a workload into a sensitive segment by tagging it. The rule of
thumb: **if the segment is sensitive and the attachment owner is not you, require
acceptance.** See [`infra/5-multi_account`](../infra/5-multi_account/).

## Restricting a segment to some Regions

By default a segment exists in every edge location. `edge-locations` on the segment
narrows it:

```json
{
  "segments": [
    {
      "name": "emea-restricted",
      "require-attachment-acceptance": false,
      "edge-locations": ["eu-west-1"]
    }
  ]
}
```

Now the segment exists only in `eu-west-1`, and **an attachment in any other Region
cannot associate with it**. That is the enforcement: a workload in `us-east-1` tagged
for this segment will attach and fail to associate, rather than quietly joining.

Use it for data-residency requirements, where "this routing domain must not exist
outside the EU" is a control you want the network to enforce rather than a convention
you document.

## What segments do *not* do

Worth stating plainly, because these are common wrong assumptions:

- **Segments do not talk to each other by default**, and there is no "allow all". You
  declare each relationship — see [`4-segment_sharing.md`](./4-segment_sharing.md).
- **Sharing is not transitive.** A↔B and B↔C does not give you A↔C.
- **An attachment belongs to exactly one segment** — or to one network function group,
  never both.
- **Segments do not solve overlapping CIDRs.** This is IP routing; addresses must be
  unique. If overlap is your actual requirement, the answer is VPC Lattice or
  PrivateLink, not Cloud WAN.

## Constraints to carry forward

| Constraint | Consequence |
|------------|-------------|
| An attachment is in exactly one segment, or one NFG | You cannot inspect *and* associate the same attachment |
| Isolation is **required** for intra-segment inspection | Enforced by `cwan-8` |
| A segment restricted by `edge-locations` rejects attachments elsewhere | Intentional; it is the residency control |
| Segment sharing is applied **after** attachment policies | Association happens first, then reachability |
| Segments are global by default | Adding an edge location extends every segment |

## Next

[`3-attachment_policies.md`](./3-attachment_policies.md) — how attachments actually get
into these segments. It is where most designs break.

## Reference

- [Core network policy parameters](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html)
- [Attachment acceptance](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-attachments.html)
