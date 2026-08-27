---
title: "Cloud WAN static routes: create-route and blackhole routes in a segment"
description: "How the create-route segment action writes an explicit route or a blackhole into one AWS Cloud WAN segment's route table, why a static route never crosses a segment share, and why fewer destinations than Regions does not scope a route. Includes the two-pass deployment that naming attachment IDs forces, and why to reach for another capability first."
---

# Static routes

A [`create-route`](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html#cloudwan-segment-actions-json) action writes a static route into one segment's route table. Everything else in a policy propagates routes that already exist somewhere; this is the one place you state a route outright, whatever the attachments advertise.

> **Avoid a static route unless a requirement leaves no alternative.** Sharing, service insertion and routing policies all keep working as attachments come and go. A static route does not: it applies to a single segment, names attachments by ID, and any change to either means editing the LIVE policy.

The `segment-actions` array is optional. Every field a `create-route` entry accepts appears below:

```json
{
  "segment-actions": [
    {
      "action": "create-route",
      "segment": "production",
      "destination-cidr-blocks": ["10.100.0.0/16"],
      "destinations": ["attachment-05e1da91f4a52b4e6"],
      "description": "Reach the transport VPC in the hybrid segment"
    }
  ]
}
```

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `action` | Which segment action this entry is — `create-route` for a static route | Yes | `share` |
| `segment` | The segment whose route table receives the route | Yes | — |
| `destination-cidr-blocks` | The prefixes being routed | Yes | — |
| `destinations` | Where matching traffic is sent | Yes | — |
| `description` | A free-text description | No | — |

## `segment`

One segment name, with no array and no wildcard. A route that needs to be applied to several segments means several entries (one per segment).

```json
{
  "action": "create-route",
  "segment": "production"
}
```

Nor does it travel once created: a static route [never crosses a share](./4-segment_sharing.md), so sharing `production` with `hybrid` leaves `hybrid` without it. One entry per segment and no propagation between them is what makes static routes the part of a policy that grows fastest and ages worst.

## `destination-cidr-blocks`

An array of prefixes, IPv4 or IPv6 or both.

```json
{
  "destination-cidr-blocks": ["10.100.0.0/16", "2001:db8::/56"]
}
```

Every prefix listed resolves to the same `destinations`, so group them only where they share a next hop. Keep the routing behaviour consistent across Regions: **if one Region has a route to a destination, the others should too**, even by a different path.

## `destinations`

Where matching traffic goes, in one of two mutually exclusive forms. Attachment IDs send it to specific attachments, **up to one per Region**:

```json
{
  "destinations": ["attachment-05e1da91f4a52b4e6"]
}
```

> **Fewer destinations than Regions does not scope the route.** Regions with no attachment in the list receive a propagated version through cross-Region peering and use another Region's static route. A single destination gives the whole segment one exit point for that prefix, rather than a route in one Region.

Attachment IDs also force an ordering problem: the ID must exist before a policy can name it, and the attachment cannot exist before a policy it can associate with. So a network using static routes takes two passes — apply a policy that creates the core network and lets the attachments be made, collect the IDs, then apply a second version carrying the routes. Every attachment replacement repeats the second pass, which is reason enough on its own to look elsewhere first.

`["blackhole"]` discards traffic instead, and needs no attachment, so it carries neither problem:

```json
{
  "destinations": ["blackhole"]
}
```

> **The two forms differ in reach.** With an attachment destination, the route is advertised over BGP to that attachment's peer. `["blackhole"]` is not advertised anywhere — it only drops traffic inside the segment.
