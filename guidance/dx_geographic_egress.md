---
title: "Cloud WAN routing policies and BGP communities: prefer same-geography Direct Connect egress with cross-geography failover"
description: "Use one Direct Connect gateway per geography, tag routes with a BGP community per geography on-premises, and lengthen the other geographies' routes with AS_PATH prepending so each Region exits through the nearest Direct Connect while keeping remote failover paths. Covers identifying the geography by the Direct Connect gateway's ASN, and ranking with local preference or MED."
---

# Egress through the same-geography Direct Connect gateway, with cross-geography failover

| | |
|---|---|
| **Applies when** | You want "hot-potato routing": Direct Connect lands in more than one geographic area, each location announces the same routes, and AWS traffic should use the same-geography exit first while retaining another geography as failover |
| **Composes** | [`7-routing_policies.md`](../policy/7-routing_policies.md) (`community-in-list`, `prepend-asn-list`, rule evaluation) and [`9-attachment_routing_policy_rules.md`](../policy/9-attachment_routing_policy_rules.md) (routing-policy labels, `edge-locations` scoping) |
| **Test on** | [`4-hybrid`](../infra/4-hybrid/) — it creates the `vpc` and `direct-connect-gateway` attachment types this policy expects. To reproduce this scenario, add a second Direct Connect gateway and edge locations in a second geography |

## The scenario

Suppose your organization has on-premises networks in Europe and Asia-Pacific, with redundant Direct Connect connections in each geography. Every location can carry any traffic, so they all announce the same routes to AWS. That might be `0.0.0.0/0`, a corporate supernet, or both.

You want European workloads to leave through the European Direct Connect connections and Asia-Pacific workloads to leave through the Asia-Pacific connections. If one geography loses its connections, its workloads should automatically use the other geography without a policy change. This is commonly called **hot-potato routing**: traffic leaves the AWS backbone at the nearest suitable exit instead of crossing the backbone to an exit closer to the destination.

A common first design is to place every virtual interface (VIF) on one Direct Connect gateway (DXGW). When several VIFs advertise the same routes with equal attributes, the DXGW can load balance traffic across them. But [a DXGW selects a single best path for each prefix before advertising it to the core network, and keeps only the communities on that best path](https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-cloud-wan.html). Every Region receives the same copy of the route, carrying one geography's identity, so a single DXGW cannot send European Regions to the European VIFs and Asia-Pacific Regions to the Asia-Pacific VIFs.

Using **one DXGW per geography** fixes that: each geography's copy of the route reaches the core network on its own, with its own BGP community. The design then has to satisfy two goals at the same time:

1. **Keep every exit usable from every Region.** [An edge advertises its local routes only toward associated DXGW attachments](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-dxattach-about.html), so each DXGW must be associated with every edge location. Otherwise, the remote on-premises routers do not learn the return routes they need when traffic fails over across geographies.
2. **Prefer the local exit without removing the remote exits.** Associating every DXGW everywhere means each edge learns the same routes from all of them. The routing policy must make the local path win at each edge while leaving the remote paths installed.

These goals are linked: global association provides cross-geography reachability but creates equally viable routes, and a Region-scoped routing policy breaks that tie without taking the failover paths away.

## The design

| Part | What it does |
|---|---|
| **One DXGW per geography, associated with every edge** | Delivers each geography's copy of the route to every CNE, and keeps outbound and return paths available during failover |
| **A BGP community per geography, set on-premises** | Gives each route its geography identity, which travels with the route into the core network |
| **An inbound policy per tagged geography that lengthens that geography's routes** | Makes the same-geography route win at each CNE without removing the others |
| **A Region-scoped attachment routing policy rule** | Attaches the other geographies' policies at each geography's CNEs, because "local" means something different at every CNE |

Because the community identifies the geography, the routing policies never need to know which DXGW a route arrived on. Every DXGW attachment carries the same **routing-policy label**, which selects the attachments a rule applies to. The rule's `edge-locations` then selects the CNEs where it applies. Each policy is named for what it does: `addEuropeASPath` lengthens the routes tagged Europe and is attached at the Asia-Pacific CNEs, so they prefer the untouched Asia-Pacific routes; `addAPJASPath` does the opposite at the European CNEs. The rules stay at one per geography.

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

Neither path says "Europe." A later tie-break chooses the winner, and the result may happen to look geographic even though no policy enforces it. The next steps remove that ambiguity.

### `community-in-list` and `prepend-asn-list`: identify the geography by its tag, rank exits by AS_PATH length

**Step 1: tag the routes on-premises.** Each geography's routers add one community, unique to that geography, to everything they announce over Direct Connect. This example uses `65052:100` for Europe and `65052:200` for Asia-Pacific. Pick a scheme that Direct Connect preserves: standard communities only, with an ASN you own in the first position — never one of the core network's [`asn-ranges`](../policy/1-core_network_version_configuration.md#asn-ranges) or an [ASN reserved by AWS](https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-cloud-wan.html).

Every router in a geography, on every VIF, must set the same tag. For example router configurations, see [Tag routes on-premises](#tag-routes-on-premises) in the annex.

**Step 2: one inbound policy per tagged geography, lengthening its routes.** `addEuropeASPath` matches the Europe tag and prepends two ASNs. Applied at the Asia-Pacific CNEs, it makes the European routes the longer path there, so they stay installed as the fallback while the untouched Asia-Pacific routes win:

```json
{
  "routing-policies": [
    {
      "routing-policy-name": "addEuropeASPath",
      "routing-policy-direction": "inbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              {
                "type": "community-in-list",
                "value": "65052:100"
              }
            ],
            "condition-logic": "or",
            "action": {
              "type": "prepend-asn-list",
              "value": [65200, 65200]
            }
          }
        }
      ]
    }
  ]
}
```

`addAPJASPath` is the mirror image: it prepends to routes tagged `65052:200`, and is applied at the European CNEs. The action is [non-terminal](../policy/7-routing_policies.md#how-rules-are-evaluated), and there is no catch-all `drop`, so no `allow` is needed to protect what the rule produces. The prepended ASNs [must not overlap the core network's `asn-ranges`](../policy/7-routing_policies.md#prepend-asn-list-as_path-prepending-to-prefer-one-regions-hybrid-edge).

AS_PATH prepending makes the remote exit less attractive without overriding the rest of path selection. If you need the ranking to win regardless of AS_PATH length, see [other ways to rank the exits](#rank-the-exits-with-local-preference-or-med).

**Step 3: bind each policy to the other geography's edges.** Because the policy matches the tag rather than the attachment, every DXGW can carry the **same** label, here `dxAttachment`. One rule per geography then decides which ranking applies where:

```json
{
  "attachment-routing-policy-rules": [
    {
      "rule-number": 100,
      "description": "Lengthen Asia-Pacific routes at the European Regions",
      "edge-locations": ["eu-west-2", "eu-central-1"],
      "conditions": [
        {
          "type": "routing-policy-label",
          "value": "dxAttachment"
        }
      ],
      "action": {
        "associate-routing-policies": ["addAPJASPath"]
      }
    },
    {
      "rule-number": 200,
      "description": "Lengthen European routes at the Asia-Pacific Regions",
      "edge-locations": ["ap-southeast-2", "ap-southeast-1"],
      "conditions": [
        {
          "type": "routing-policy-label",
          "value": "dxAttachment"
        }
      ],
      "action": {
        "associate-routing-policies": ["addEuropeASPath"]
      }
    }
  ]
}
```

The `edge-locations` scope is essential: [without it, a rule applies at every CNE associated with the attachment](../policy/9-attachment_routing_policy_rules.md#edge-locations), and both geographies' routes would be lengthened everywhere, recreating the tie. At a European CNE, where `addAPJASPath` applies, the earlier tie now looks like this:

```
0.0.0.0/0  via dxgw-europe  AS_PATH [65000, 65052]                COMMUNITY 65052:100   <- preferred
0.0.0.0/0  via dxgw-apj     AS_PATH [65200, 65200, 65001, 65552]  COMMUNITY 65052:200
```

The shorter AS_PATH wins. The Asia-Pacific route stays installed; if the European DXGW withdraws its route, the CNE selects it without a policy change.

### `routing-policy-label`: set it on each DXGW, ideally at creation time

The attachment rules match labels, and **the label lives on the attachment**. Every DXGW carries the same label, `dxAttachment` above. Set each label **when you create the attachment** whenever possible. Adding it later creates a window in which the DXGW is associated with the segment and advertising routes but no routing policy is bound, leaving route selection to the original tie-break.

Plan this sequence carefully in a multi-account deployment. [With a cross-account core network, the attachment owner cannot set its own routing-policy label](../policy/9-attachment_routing_policy_rules.md#creation-time-dependency): the spoke account creates the attachment, and the core network owner applies the label.

## Constraints that bite here

- **Direct Connect preserves only some communities.** [Standard communities sent over the transit VIF reach the core network; large communities (RFC 8092), extended communities such as route targets, and communities whose first value is an AWS-reserved ASN (`7224`, `10124`, `17493`, `9059`, `4001`) are removed](https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-cloud-wan.html). A removed tag fails silently: the route arrives untagged, matches no rule, and falls back to the tie-break. Use standard communities for the geography tags.
- **One DXGW carries one geography's tag per prefix.** The DXGW keeps only its best path's communities, so putting two geographies' VIFs on one DXGW loses one geography's identity before Cloud WAN sees it.
- **An untagged route, or an unlabeled attachment, matches nothing, silently.** A router that skips the `set community`, and an attachment without its [routing-policy label](../policy/9-attachment_routing_policy_rules.md#creation-time-dependency), both deploy cleanly while ranking nothing. Route selection then falls back to the tie-break and may still look correct by coincidence. Always verify.
- **Community values must not contain an ASN the core network uses.** [ASNs in community tags cannot overlap the core network's `asn-ranges`, and you cannot advertise communities containing an ASN in use by the core network](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html). The same applies to prepended ASNs.
- **A new Region has to be added in two places.** Add the edge location to the DXGW attachments, then add the Region to the `edge-locations` list of the rule for its geography. If you stop after the first step, the new CNE learns every DXGW's routes but [has no scoped rule to distinguish them](../policy/9-attachment_routing_policy_rules.md#edge-locations).

## Verification

This design can appear correct even when the policy did not bind, so verify the inputs, the control plane and the failover behavior separately.

**1. Confirm the tags arrive.** The [routing information base](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-visualize-networks-core.html) shows every route candidate with its BGP attributes, communities included, before routing policies are applied — which is exactly the view you need here: each DXGW's routes should carry their geography's community. A route that arrives without it was never tagged or had its tag removed by Direct Connect, and no policy will rank it.

```bash
aws networkmanager list-core-network-routing-information \
  --core-network-id <core-network-id> \
  --segment-name vpcs \
  --edge-location eu-central-1
```

**2. Confirm what actually bound.** For each DXGW attachment, check its routing-policy label, the policies associated with it, and the edge locations where each association applies. Every DXGW should show `addAPJASPath` at the European edges and `addEuropeASPath` at the Asia-Pacific edges. Nothing should be pending.

```bash
aws networkmanager list-attachment-routing-policy-associations \
  --core-network-id <core-network-id>
```

**3. Confirm which DXGW wins in each Region.** Run `get-network-routes` for each edge location and verify that the prefix resolves to the same-geography DXGW attachment. Use this API rather than `list-core-network-routing-information`, which [returns the pre-policy view](../policy/7-routing_policies.md#get-network-routes-versus-list-core-network-routing-information-verify-policy-effects-with-the-right-api).

```bash
aws networkmanager get-network-routes \
  --global-network-id <global-network-id> \
  --route-table-identifier '{"CoreNetworkSegmentEdge":{"CoreNetworkId":"<core-network-id>","SegmentName":"vpcs","EdgeLocation":"eu-central-1"}}'
```

**4. Confirm that failover works, not just preference.** In a test environment or controlled maintenance window, withdraw the route advertisement from one geography or take its VIFs down. Query the same route tables again. The affected CNEs should converge on the other DXGW's lower-ranked path without a policy change.

## FAQ

### How do I rank three or more areas — active, first passive, second passive?

Use the prepend depth as the rank. Give each tagged geography one policy per fallback tier, named for both, such as `addAPJASPathTier1` (two ASNs on `65052:200`) and `addAmericasASPathTier2` (four ASNs on `65052:300`). Each geography's attachment rule then lists the policies for its own order: the European rule attaches `addAPJASPathTier1` and `addAmericasASPathTier2`, while the Asia-Pacific rule can attach `addAmericasASPathTier1` and `addEuropeASPathTier2`. Policies on the same attachment need distinct `routing-policy-number` values. Routes from the local geography are never matched, and the attachment rules stay at one per geography, all matching the shared label. Leaving space between depths, such as two and four ASNs, lets you insert a tier later.

### Does this also control which Direct Connect the on-premises network uses to reach AWS?

No. Every policy on this page is `inbound`, so it acts on routes the core network **learns** and controls only how traffic leaves AWS. Your on-premises routers choose the Direct Connect path in the other direction from the routes AWS advertises to them.

For that reverse direction, apply **outbound** treatment to the same attachments so each Region's prefixes, or shorter paths, are advertised through the same-geography DXGW. See [one summary per Region on a Direct Connect gateway](../policy/7-routing_policies.md#direct-connect-gateway-needs-one-summary-per-region-scoped-with-edge-locations). Communities work in this direction too: [Cloud WAN can propagate them back to on-premises over Direct Connect](https://aws.amazon.com/about-aws/whats-new/2026/11/cloud-wan-bgp-community-directconnect/), so an outbound policy with `add-community`, scoped per Region with `edge-locations`, can tag each Region's routes and let your on-premises routers set their own local preference from that tag. Symmetric routing requires both directions to behave as intended, so verify them separately.

## Annex

### Identify the geography by the DXGW's ASN

If on-premises cannot tag routes, the AS_PATH already says which DXGW a route came through: each DXGW adds its Amazon-side ASN, `65000` for Europe and `65001` for Asia-Pacific in the examples above. An `asn-in-as-path` condition on the other geography's DXGW ASN replaces the community condition, and the rest of the design stays the same: `addAPJASPath` now matches `65001` and is still applied at the European CNEs, with one shared label and one rule per geography.

```json
{
  "routing-policies": [
    {
      "routing-policy-name": "addAPJASPath",
      "routing-policy-direction": "inbound",
      "routing-policy-number": 100,
      "routing-policy-rules": [
        {
          "rule-number": 100,
          "rule-definition": {
            "match-conditions": [
              {
                "type": "asn-in-as-path",
                "value": 65001
              }
            ],
            "condition-logic": "or",
            "action": {
              "type": "prepend-asn-list",
              "value": [65200, 65200]
            }
          }
        }
      ]
    }
  ]
}
```

This needs a distinct Amazon-side ASN on every DXGW, and it ties the policy to your AWS topology instead of to an intent declared at the source: a new or replaced DXGW means editing the policy that matches its ASN. Confirm in the routing information base that each DXGW's ASN appears in its routes' AS_PATH before you rely on it.

### Identify the geography with one label per DXGW

Another option is one routing-policy label per DXGW, `dxAttachmentEurope` and `dxAttachmentAPJ`, with an attachment rule per DXGW and per geography that treats it as remote. The policy then matches the announced prefixes instead of a tag, as in [`prepend-asn-list`](../policy/7-routing_policies.md#prepend-asn-list-as_path-prepending-to-prefer-one-regions-hybrid-edge), but the rules grow as *areas × (areas − 1)*.

### Rank the exits with local preference or MED

Whichever way you identify the geography, the action that ranks the routes can also be:

- **`set-local-preference`.** [Local preference is compared before AS_PATH length](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-route-evaluation.html), so the ranking holds even when the paths' AS_PATHs differ in length for reasons unrelated to geography. Set an explicit value for every tag, for example `300` for the local geography and `200` for the remote one, so the result never depends on a default.
- **`set-med`.** MED is compared after local preference and AS_PATH length, so it decides only when both are equal. It is the weakest lever of the three, and on policy [`version`](../policy/1-core_network_version_configuration.md#what-202610-changes) `2026.10` cross-Region routes also carry a default MED that AWS Cloud WAN sets.

Use one ranking action per design. Mixing them on the same routes makes the outcome depend on which attribute is compared first, not on the values you chose.

### Tag routes on-premises

These examples show a European router adding the Europe tag `65052:100` to the routes it announces over Direct Connect. They use standard vendor syntax; adapt the prefix lists, neighbor addresses and group names to your network.

#### Cisco IOS XE

A European router tags what it announces to its Direct Connect BGP peer with an outbound route map. The prefix list limits the tag to the routes you announce to AWS, and `additive` keeps any communities the routes already carry. IOS XE does not send communities unless `send-community` is set on the neighbor:

```
ip prefix-list TO-AWS seq 10 permit 0.0.0.0/0
ip prefix-list TO-AWS seq 20 permit 10.0.0.0/8
!
route-map TO-AWS permit 10
 match ip address prefix-list TO-AWS
 set community 65052:100 additive
!
router bgp 65052
 address-family ipv4 unicast
  neighbor 169.254.10.1 send-community
  neighbor 169.254.10.1 route-map TO-AWS out
```

#### Junos

The same tag goes in the export policy of the Direct Connect BGP group; `community add` keeps existing communities, and Junos sends communities by default:

```
policy-options {
    prefix-list TO-AWS {
        0.0.0.0/0;
        10.0.0.0/8;
    }
    community GEO-EUROPE members 65052:100;
    policy-statement TO-AWS {
        term tag-geography {
            from prefix-list TO-AWS;
            then {
                community add GEO-EUROPE;
                accept;
            }
        }
        term reject-rest {
            then reject;
        }
    }
}
protocols {
    bgp {
        group aws-dx {
            export TO-AWS;
        }
    }
}
```

The Asia-Pacific routers do the same with `65052:200`. To tag only some routes, or to give some routes a different tag, add further route-map sequences or policy terms with their own prefix lists. Check what each router actually sends before relying on it, with `show bgp ipv4 unicast neighbors <peer> advertised-routes` on IOS XE or `show route advertising-protocol bgp <peer> detail` on Junos.
