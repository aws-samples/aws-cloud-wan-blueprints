# Edge location routing policy associations

Use the [`associate-routing-policy`](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html#cloudwan-segment-actions-json) action to apply existing [routing policies](./7-routing_policies.md) to routes crossing one Core Network Edge (CNE) pair in one segment. This edge-pair scope shapes inter-Region propagation without changing an attachment or segment share. It requires policy [`version`](./1-core_network_version_configuration.md#version) `2025.11` or later.

> **Each associated policy is unidirectional.** It acts on only one flow across the pair; use a policy in the reverse direction to govern both.

Each name in the association must be defined in [`routing-policies`](./7-routing_policies.md). An `associate-routing-policy` entry has these fields:

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `action` | Which segment action this entry is — `associate-routing-policy` | Yes | `share` |
| `segment` | The segment whose inter-Region propagation the policies apply to | Yes | — |
| `edge-location-association` | The edge pair, and the policies to apply between them | Yes | — |

## `action` and `segment`

`share` is the default action, so `associate-routing-policy` always has to be stated. `segment` names one segment — the association acts only on that segment's routes crossing between the two edges, not on every segment using the peering.

```json
{
  "action": "associate-routing-policy",
  "segment": "production"
}
```

Add a separate entry for every additional segment that needs the same treatment.

## `edge-location-association`

The pair of Regions, and the policies applied between them:

| Item | What it sets | Required |
|------|--------------|----------|
| `edge-location` | The first edge of the pair — the reference point for direction | Yes |
| `peer-edge-location` | The edge that completes the pair | Yes |
| `routing-policy-names` | The routing policies to apply between the two | Yes |

```json
{
  "action": "associate-routing-policy",
  "segment": "production",
  "edge-location-association": {
    "edge-location": "us-east-1",
    "peer-edge-location": "eu-west-1",
    "routing-policy-names": ["interRegionRouteFilter"]
  }
}
```

One entry governs one edge pair for one segment. Add an entry for each additional pair that needs edge-pair policy treatment.

> **No association means no edge-pair policy.** A pair without an entry continues under default-allow propagation, subject to filtering at other applicable scopes.

## Read direction from `edge-location`

> **The action does not set direction.** Each referenced policy's `routing-policy-direction` is interpreted from `edge-location`, the first-named edge; `peer-edge-location` is the other side of the pair.

For the configuration above:

| Policy direction | Routes affected |
|------------------|-----------------|
| `inbound` | `eu-west-1` → `us-east-1` |
| `outbound` | `us-east-1` → `eu-west-1` |

Reversing the two edge fields preserves the pair but reverses the meaning of every attached policy direction. Choose one ordering convention and use it consistently.

> **Changing an association touches exactly two Regions.** Adding or removing an `associate-routing-policy` entry triggers an update only in the two named edge locations — unlike a share, which updates every edge location in the segment.
