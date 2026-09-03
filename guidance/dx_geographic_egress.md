---
title: "Cloud WAN routing policies: prefer same-geography Direct Connect egress with cross-geography failover"
description: "Use one Direct Connect gateway per geography, attachment labels, Region-scoped rules, and inbound AS_PATH prepending to keep traffic on the nearest exit while retaining remote failover paths."
---

# Egress through the same-geography Direct Connect gateway, with cross-geography failover

| | |
|---|---|
| **Applies when** | You want "hot-potato routing": Direct Connect lands in more than one geographic area, each location announces the same routes, and AWS traffic should use the same-geography exit first while retaining another geography as failover |
| **Composes** | [`7-routing_policies.md`](../policy/7-routing_policies.md) (`prepend-asn-list`, rule evaluation) and [`9-attachment_routing_policy_rules.md`](../policy/9-attachment_routing_policy_rules.md) (routing-policy labels, `edge-locations` scoping) |
| **Test on** | [`4-hybrid`](../infra/4-hybrid/) — it creates the `vpc` and `direct-connect-gateway` attachment types this policy expects. To reproduce this scenario, add a second Direct Connect gateway and edge locations in a second geography |

## The scenario

Suppose your organization has on-premises networks in Europe and Asia-Pacific, with redundant Direct Connect connections in each geography. Every location can carry any traffic, so they all announce the same routes to AWS. That might be `0.0.0.0/0`, a corporate supernet, or both.

You want European workloads to leave through the European Direct Connect connections and Asia-Pacific workloads to leave through the Asia-Pacific connections. If one geography loses its connections, its workloads should automatically use the other geography without a policy change. This is commonly called **hot-potato routing**: traffic leaves the AWS backbone at the nearest suitable exit instead of crossing the backbone to an exit closer to the destination.

A common first design is to place every virtual interface (VIF) on one Direct Connect gateway (DXGW). When several VIFs advertise the same routes with equal attributes, the DXGW can load balance traffic across them. You can use BGP attributes to influence which path the DXGW prefers, but that preference applies to the route as a whole; it cannot express "use the European VIFs for traffic from European Regions and the Asia-Pacific VIFs for traffic from Asia-Pacific Regions." A single DXGW therefore cannot provide deterministic same-geography egress.

Using **one DXGW per geography** gives Cloud WAN a separate attachment for each geographic exit. That creates the control point you need, but the design still has to satisfy two goals at the same time:

1. **Keep every exit usable from every Region.** [An edge advertises its local routes only toward associated DXGW attachments](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-dxattach-about.html), so each DXGW must be associated with every edge location. Otherwise, the remote on-premises routers do not learn the return routes they need when traffic fails over across geographies.
2. **Prefer the local exit without removing the remote exits.** Associating every DXGW everywhere means each edge learns the same routes from all of them. The routing policy must make the remote paths longer at each edge while leaving the local path unchanged.

These goals are linked: global association provides cross-geography reachability but creates equally viable routes, and Region-scoped AS_PATH prepending breaks that tie without taking the failover paths away.

## The design

The design has three parts, plus one prerequisite that lives outside the policy document:

| Part | What it does |
|---|---|
| **One DXGW per geography, associated with every edge** | Gives Cloud WAN a distinct attachment for each exit and preserves outbound and return-path reachability during failover |
| **An inbound routing policy using `prepend-asn-list`** | Makes selected DXGW routes less preferred by increasing their AS_PATH length |
| **A Region-scoped attachment routing policy rule per DXGW** | Applies the prepend only where that DXGW is remote, leaving its path unchanged in its home geography |

Each DXGW attachment also needs a **routing-policy label**. The label lives on the attachment, outside the core network policy document, and gives the attachment routing policy rules something stable to match.

In the two-geography example, the binding is crossed:

* Apply the prepend policy to the European DXGW at the Asia-Pacific Regions.
* Apply the prepend policy to the Asia-Pacific DXGW at the European Regions.

The local DXGW keeps its original, shorter path. The remote DXGW remains installed with a longer path, ready to take over if the local DXGW withdraws its routes.

### `direct-connect-gateway` attachments: one per geography, associated everywhere — the setup, not yet the solution

Keeping each geography's VIFs on its own DXGW gives you one Cloud WAN attachment per geographic exit. Associating every attachment with **all** edge locations provides both halves of failover:

* **Egress.** While both DXGWs advertise the matched prefix, every CNE has a route through each one. If the local DXGW withdraws the route, the remote path is already available.
* **Return.** [Each edge advertises only its local routes toward DXGWs associated with that attachment](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-dxattach-about.html). Associating every DXGW with every edge therefore advertises each Region's prefixes to every on-premises side, including the return routes needed during cross-geography failover.

It can be tempting to associate each DXGW only with edges in its own geography. That design may even appear to provide local egress without a routing policy: routes can cross the CNE mesh to other Regions, and each crossing lengthens their AS_PATH. The problem is the return direction. The remote on-premises side never learns about the Regions it would need to reach during failover, so traffic can leave through the backup geography but cannot return.

Global association solves reachability, not preference. Each CNE now learns the same prefix from both DXGWs. If MED, local preference, and AS_PATH length are equal, the routes are indistinguishable. At a European CNE, for example, the candidate paths might look like this:

```
0.0.0.0/0  via dxgw-europe  AS_PATH [65000, 65052]
0.0.0.0/0  via dxgw-apj     AS_PATH [65001, 65552]
```

Neither path says "Europe." A later tie-break chooses the winner, and the result may happen to look geographic even though no policy enforces it. The next two steps remove that ambiguity.

### `prepend-asn-list` inbound: one policy that lengthens the routes it is applied to

Use an **inbound** routing policy to lengthen selected routes as they enter the core network, before a CNE compares them. This example matches a default route advertised from on-premises and prepends two ASNs:

```json
{
  "routing-policies": [
    {
      "routing-policy-name": "addASNPath",
      "routing-policy-direction": "inbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              {
                "type": "prefix-equals",
                "value": "0.0.0.0/0"
              }
            ],
            "condition-logic": "or",
            "action": {
              "type": "prepend-asn-list",
              "value": [65200, 65201]
            }
          }
        }
      ]
    }
  ]
}
```

> **Match what your on-premises routers actually announce.** If they advertise a corporate supernet such as `10.0.0.0/8`, replace `0.0.0.0/0` with that prefix. If you also need to lengthen more-specific prefixes, add a `prefix-in-cidr` condition for the same value alongside `prefix-equals`. [`prefix-in-cidr` does not match the containing prefix itself](../policy/7-routing_policies.md#routing-policy-rules), so the two conditions work together with `condition-logic` set to `or`. A condition that matches nothing does not produce a deployment error; it simply leaves the original tie in place.

For the smallest two-geography design, **one shared policy is enough**. The policy acts on routes, not on a named DXGW or Region. You can apply `addASNPath` to the European attachment at one set of CNEs and to the Asia-Pacific attachment at another set, and it performs the same action in both places.

As the design grows, two refinements make it easier to operate:

- **Use one routing policy per remote DXGW**, such as `prependAPJRoutes` and `prependEuropeRoutes`. The names show exactly which routes receive the treatment, and you can change one geography's prepend depth or filtering without affecting the others. Separate policies are also the natural starting point for [ranking three or more areas](#how-do-i-rank-three-or-more-areas--active-first-passive-second-passive).
- **Choose prepend values that identify the route source.** For example, you could repeat the DXGW's Amazon-side ASN (`[65001, 65001]` for Asia-Pacific) instead of using arbitrary values. That makes a route table easier to read during verification and troubleshooting: you can see which DXGW advertised the route and what the policy added. Whatever values you choose, they [must not overlap the core network's `asn-ranges`](../policy/7-routing_policies.md#prepend-asn-list-as_path-prepending-to-prefer-one-regions-hybrid-edge).

### `attachment-routing-policy-rules`: apply it to the other geography's DXGW, per Region

The routing policy does nothing until an attachment routing policy rule binds it to a DXGW. Create one rule per DXGW and use these two fields to control the binding:

| Field | Role in this design |
|---|---|
| **`conditions`** | Matches the DXGW through its [routing-policy label](../policy/9-attachment_routing_policy_rules.md#conditions), which is [set on the attachment](#routing-policy-label-set-it-on-each-dxgw-ideally-at-creation-time) |
| **`edge-locations`** | Limits the rule to Regions where that DXGW is a remote, non-preferred exit |

The `edge-locations` scope is essential. [If you omit it, the policy applies at every CNE associated with the attachment](../policy/9-attachment_routing_policy_rules.md#edge-locations), including the DXGW's home geography. Both routes would then be lengthened everywhere, recreating the tie you intended to remove.

The European DXGW therefore receives the prepend at the Asia-Pacific Regions, and the Asia-Pacific DXGW receives it at the European Regions:

```json
{
  "attachment-routing-policy-rules": [
    {
      "rule-number": 100,
      "description": "Deprioritize the European DXGW at the Asia-Pacific Regions",
      "edge-locations": ["ap-southeast-2", "ap-southeast-1"],
      "conditions": [
        {
          "type": "routing-policy-label",
          "value": "dxAttachmentEurope"
        }
      ],
      "action": {
        "associate-routing-policies": ["addASNPath"]
      }
    },
    {
      "rule-number": 200,
      "description": "Deprioritize the Asia-Pacific DXGW at the European Regions",
      "edge-locations": ["eu-west-2", "eu-central-1"],
      "conditions": [
        {
          "type": "routing-policy-label",
          "value": "dxAttachmentAPJ"
        }
      ],
      "action": {
        "associate-routing-policies": ["addASNPath"]
      }
    }
  ]
}
```

No rule modifies a DXGW's route in its home geography, so the local path stays short. At a European CNE, the previous tie now looks like this:

```
0.0.0.0/0  via dxgw-europe  AS_PATH [65000, 65052]                 <- preferred
0.0.0.0/0  via dxgw-apj     AS_PATH [65200, 65201, 65001, 65552]
```

Assuming the paths are otherwise comparable, the European DXGW wins because its AS_PATH is shorter. The Asia-Pacific route is still present; if the European DXGW withdraws its route, the CNE can immediately select the remaining path.

### `routing-policy-label`: set it on each DXGW, ideally at creation time

The attachment rules match labels, and **the label lives on the attachment**. In this example, the DXGW attachments need the labels `dxAttachmentEurope` and `dxAttachmentAPJ`.

Set each label **when you create the attachment** whenever possible. Adding it later creates a window in which the DXGW is associated with the segment and advertising routes but no routing policy is bound, leaving route selection to the original tie-break.

Plan this sequence carefully in a multi-account deployment. [With a cross-account core network, the attachment owner cannot set its own routing-policy label](../policy/9-attachment_routing_policy_rules.md#creation-time-dependency): the spoke account creates the attachment, and the core network owner applies the label.

## Constraints that bite here

- **An unlabeled attachment matches no rule, silently.** The label is [set on the attachment](../policy/9-attachment_routing_policy_rules.md#creation-time-dependency). A valid policy and an unlabeled attachment can both deploy successfully while associating no routing policy. Route selection then falls back to the tie-break and may still look correct by coincidence. Always verify the association.
- **A new Region has to be added in two places.** Add the edge location to the DXGW attachments, then add the Region to the `edge-locations` lists for the rules that should apply there. If you stop after the first step, the new CNE learns every DXGW's routes but [has no scoped rule to distinguish them](../policy/9-attachment_routing_policy_rules.md#edge-locations).
- **Direct Connect strips BGP communities.** You cannot tag routes by geography on-premises and match them with `community-in-list` over Direct Connect. [Use AS_PATH for this scenario instead](../policy/7-routing_policies.md#community-in-list-filtering-routes-by-bgp-community).

## Verification

This design can appear correct even when the policy did not bind, so verify the control plane and the failover behavior separately.

**1. Confirm what actually bound.** For each DXGW attachment, check its routing-policy label, the policies associated with it, and the edge locations where each association applies. Every DXGW should show the prepend policy at the *other* geography's edges, with nothing pending.

```bash
aws networkmanager list-attachment-routing-policy-associations \
  --core-network-id <core-network-id>
```

**2. Confirm which DXGW wins in each Region.** Run `get-network-routes` for each edge location and verify that the prefix resolves to the same-geography DXGW attachment. Use this API rather than `list-core-network-routing-information`, which [returns the pre-policy view](../policy/7-routing_policies.md#get-network-routes-versus-list-core-network-routing-information-verify-policy-effects-with-the-right-api).

```bash
aws networkmanager get-network-routes \
  --global-network-id <global-network-id> \
  --route-table-identifier '{"CoreNetworkSegmentEdge":{"CoreNetworkId":"<core-network-id>","SegmentName":"vpcs","EdgeLocation":"eu-central-1"}}'
```

**3. Confirm that failover works, not just preference.** In a test environment or controlled maintenance window, withdraw the route advertisement from one geography or take its VIFs down. Query the same route tables again. The affected CNEs should converge on the other DXGW's prepended path without a policy change.

## FAQ

### How do I rank three or more areas — active, first passive, second passive?

With more than two areas, each geography needs an explicit ranking for every remote DXGW. Use different prepend depths to represent those ranks: the local path remains unchanged, the first fallback receives a shorter prepend, and the second fallback receives a longer one.

Define one reusable policy per fallback tier. The policies differ only in the number of ASNs they prepend:

```json
{
  "routing-policies": [
    {
      "routing-policy-name": "prependTier1",
      "routing-policy-direction": "inbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              {
                "type": "prefix-equals",
                "value": "0.0.0.0/0"
              }
            ],
            "condition-logic": "or",
            "action": {
              "type": "prepend-asn-list",
              "value": [65201, 65201]
            }
          }
        }
      ]
    },
    {
      "routing-policy-name": "prependTier2",
      "routing-policy-direction": "inbound",
      "routing-policy-number": 110,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              {
                "type": "prefix-equals",
                "value": "0.0.0.0/0"
              }
            ],
            "condition-logic": "or",
            "action": {
              "type": "prepend-asn-list",
              "value": [65202, 65202, 65202, 65202]
            }
          }
        }
      ]
    }
  ]
}
```

Then assign a tier to every remote DXGW at each geography. If Europe uses Asia-Pacific as its first fallback and the Americas as its second, apply `prependTier1` to `dxAttachmentAPJ` and `prependTier2` to `dxAttachmentAmericas`, with both rules scoped to the European `edge-locations`.

A single label can match several rules because different geographies may rank the same DXGW differently. For example, `dxAttachmentAmericas` can receive `prependTier2` at European edges and `prependTier1` at Asia-Pacific edges. [Cloud WAN supports several rules matching the same label, with each rule applying only at its own `edge-locations`](../policy/9-attachment_routing_policy_rules.md#different-routing-policies-per-cne-on-one-attachment). The label identifies the DXGW; `edge-locations` selects the geography's ranking.

The number of rules grows as *areas × (areas − 1)* because every geography ranks every other DXGW. Keep the tier policies shared and reusable, and put the geography-specific ranking in the attachment policy rules. The prepend depths only need to produce distinct path lengths. Leaving space between tiers, such as two ASNs and four ASNs, lets you insert another tier later without redesigning the existing ones.

### Does this also control which Direct Connect the on-premises network uses to reach AWS?

No. Every policy on this page is `inbound`, so it acts on routes the core network **learns** and controls only how traffic leaves AWS. Your on-premises routers choose the Direct Connect path in the other direction from the routes AWS advertises to them.

For that reverse direction, apply **outbound** treatment to the same attachments so each Region's prefixes, or shorter paths, are advertised through the same-geography DXGW. See [one summary per Region on a Direct Connect gateway](../policy/7-routing_policies.md#direct-connect-gateway-needs-one-summary-per-region-scoped-with-edge-locations). Symmetric routing requires both directions to behave as intended, so verify them separately.
