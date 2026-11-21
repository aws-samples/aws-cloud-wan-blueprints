---
title: "Cloud WAN core network configuration: policy version, ASN ranges, edge locations and multipath resilience"
description: "How to choose the AWS Cloud WAN network policy version and what 2025.11 and 2026.10 change, how to upgrade one version at a time, how to size and pin the ASN ranges your Core Network Edges draw from, and how to declare edge locations. Also covers multipath resilience between Regions, inside CIDR blocks for Connect attachments, VPN ECMP, DNS support and security group referencing."
---

# Core network policy version and core network configuration

Before AWS Cloud WAN can route anything, it needs a presence in every AWS Region you operate in, and that presence needs a BGP identity. That is what this part of the policy decides. You name the Regions, and AWS Cloud WAN builds a **Core Network Edge (CNE)** in each one: a managed, highly available regional hub that your attachments connect to. Every CNE is automatically peered with every other and they exchange routes over [external BGP](https://aws.amazon.com/what-is/border-gateway-protocol/) (eBGP), so you never create a peering or write a route between Regions.

Everything else you will write sits on top of that. Segments only exist where there is a CNE, and attachments can only be created where their segment exists. So this is the first block you write, and it decides the shape of the rest.

It is also the block that is hardest to walk back. Most of an AWS Cloud WAN policy is an in-place edit — you can add a segment, change what is shared, or move where inspection happens on a running network. However **a Region cannot be removed while attachments still use it** and **a CNE's ASN cannot be changed at all** once assigned. Both are worth a few minutes of planning before your first deploy, which is what [`asn-ranges`](#asn-ranges) and [`edge-locations`](#edge-locations) below cover.

In the JSON this is two top-level keys, [**`version`**](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html#cloudwan-version-json) and [**`core-network-configuration`**](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html#cloudwan-network-config-json):

## `version`

A required top-level key. There are three accepted values, and the choice is a capability and behaviour gate, not a format marker. Each version keeps what the earlier ones added:

| Version | Adds | Changes in behaviour |
|---------|------|----------------------|
| `2021.12` | Segments, segment sharing, attachment policies, service insertion | — |
| `2025.11` | **Routing policies** | **BGP communities propagate** from BGP-capable attachments across the core network instead of being discarded. Their subtype is dropped in transit and set to Route Target outbound, so check anything on-premises that matches on subtypes |
| `2026.10` | — | **Ties between cross-Region routes are broken** with a default MED (Multi-Exit Discriminator): when routes through several Regions have equal local preference and AS path length and you set no preference, each CNE prefers one connected Region. See [below](#which-region-a-cne-prefers-from-202610) |

```json
{ "version": "2026.10" }
```

> [!TIP]
> **This repository recommends `2026.10` for a new core network:** starting lower buys nothing and costs you a migration later.

### Which Region a CNE prefers from `2026.10`

AWS Cloud WAN picks the preferred Region, and the documentation does not say how. Read the result instead of predicting it: for a segment, the default MED shows per prefix and edge location in the routing information base ([`list-core-network-routing-information`](./7-routing_policies.md#get-network-routes-versus-list-core-network-routing-information-verify-policy-effects-with-the-right-api) or the console). On earlier versions, [route evaluation](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-route-evaluation.html) calls the choice between such routes "deterministically random".

- **Segments:** override it with an [edge location routing policy](./8-edge_location_associations.md#pin-a-cross-region-path-before-upgrading-to-202610). Prefer `set-local-preference` over `set-med`: it is compared first, so it wins whatever the default MED is. Do this wherever the path matters (latency, egress cost, a stateful firewall).
- **Network function groups:** you can neither see nor override it.

### Upgrading between versions

Move **one version at a time**: `2021.12` → `2025.11` → `2026.10`. Each step then carries one documented behaviour change, so you know which step moved what, and the change set stays small enough to read. Schedule each step like any other network change.

| Step | What changes | Before you update |
|------|--------------|-------------------|
| `2021.12` → `2025.11` | Communities from BGP-capable attachments propagate across the core network and back out (subtype dropped in transit, set to Route Target outbound). Routing policies become available. | List the communities your routers send: they now reach other Regions and sites. Check on-premises policies that match on community values or subtypes. |
| `2025.11` → `2026.10` | Destinations with tied routes through more than one Region get a default MED, and traffic to them can **shift Region once**, when the update takes effect. | Pin the tied destinations whose path matters with an [edge location routing policy](./8-edge_location_associations.md#pin-a-cross-region-path-before-upgrading-to-202610), **while still on `2025.11`**. Paths through a network function group cannot be pinned. |

For each step:

1. **Snapshot** every segment and edge location: `get-network-routes` for the routes each CNE installs, `list-core-network-routing-information` for their attributes (communities, MED).
2. **Prepare on the current version**, as the table says. For `2026.10`, a tie candidate is a prefix learned from more than one remote edge location with equal local preference and AS path length; deploy the pins as their own policy version and confirm them before you touch `version`.
3. **Change only `version`**, then [create the policy version and read its change set](./README.md#validating-a-policy) before executing it; nothing changes until you do.
4. **Compare against the snapshot.** After `2025.11`, installed routes should not change; communities appear in the routing information base. After `2026.10`, only tied destinations you did not pin should change next hop, and they carry a default MED. Investigate anything else, and leave the core network on the new version for at least one normal change cycle before the next step.

## `core-network-configuration`

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `asn-ranges` | The pool CNE ASNs are drawn from | Yes | — |
| `inside-cidr-blocks` | Tunnel addressing for Connect attachments | No | Not set — omit unless you use Connect |
| `edge-locations` | One CNE per Region listed | Yes | — |
| `edge-locations[].location` | The Region code, such as `us-east-1` | Yes | — |
| `edge-locations[].asn` | Pins that CNE's ASN instead of letting the service choose | No | Auto-assigned from `asn-ranges` |
| `edge-locations[].inside-cidr-blocks` | That CNE's Connect tunnel addressing | No | Auto-assigned from the global `inside-cidr-blocks` |
| `multipath-resilience.mode` | Whether the core network uses multipath resilience between Regions | Yes, if `multipath-resilience` is set | Not set — off |
| `multipath-resilience.edge-sets` | Narrows the multipath resilience feature to the Region pairs listed | No | Every supported pair |
| `vpn-ecmp-support` | Load-sharing across equal-cost VPN paths | No | `true` |
| `dns-support` | Whether public EC2 hostnames resolve to private addresses across attached VPCs | No | `true` |
| `security-group-referencing-support` | Referencing security groups across attached VPCs, in inbound rules | No | `false` |

### `asn-ranges`

The pool that CNE ASNs are drawn from, and so the BGP identity of your network. Only two ranges are accepted, `64512`–`65534` and `4200000000`–`4294967294`; nothing else is valid. The range is [left-closed and right-open](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-core-network-config.html), so the first number is included and the last is not:

```json
{ "asn-ranges": ["64900-64903"] }
```

The example above gives three usable ASNs, not four: `64900`, `64901`, `64902`. Declare one more than you think you need, since every Region you add later consumes another.

Everything in the range belongs to the core network, so none of your BGP peers should use a number from it.

* A Transit Gateway is the strict case: [peering is refused](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-peerings.html) when its ASN matches that of the CNE it is trying to peer with. An ASN merely inside the range but not yet held by a CNE is accepted, but we recommend keeping the Transit Gateway outside the range — a free number can be auto-assigned to a future CNE, at which point it becomes a collision.
* Every other peer fails more quietly. An on-premises peer using a CNE's ASN establishes normally and then [loses routes in both directions](https://aws.amazon.com/blogs/networking-and-content-delivery/aws-cloud-wan-routing-policy-real-world-global-network-scenarios-part-2/) to BGP loop prevention, with nothing in the policy to show why.

Rather than let the service assign CNE ASNs, pin them:

```json
{
  "asn-ranges": ["64520-64525"],
  "edge-locations": [
    { "location": "us-east-1", "asn": 64520 },
    { "location": "eu-west-1", "asn": 64521 }
  ]
}
```

You then know which ASN belongs to which Region without looking it up: `64520` is `us-east-1`, `64521` is `eu-west-1`. Routes carry the AS_PATH of the CNEs they crossed, so when you are working out why a prefix appeared where it did, you can read which CNE advertised it straight off the path instead of calling the API to find out which CNE holds which number. Do it before the first deploy, because a CNE ASN cannot be changed afterwards.

### `inside-cidr-blocks`

Tunnel addressing for Connect attachments — infrastructure, not workload addressing. It is the pool each CNE draws its Connect addresses from, and it is needed for **both** Connect protocols, though they consume it differently:

* **GRE Connect.** The pool supplies the [core network GRE address](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-connect-peer-attachment.html), which defaults to the first free address in the CNE's block. The BGP addresses *inside* the tunnel are a separate thing you specify on the Connect peer: a `/29` from `169.254.0.0/16`.
* **Tunnel-less Connect.** Inside CIDR blocks are [not an input when you create the peer](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-connect-attachment.html) — they are taken from the CNE, which makes this pool the only place those addresses come from.

Declare a supernet globally, then carve a block per Region out of it:

```json
{
  "asn-ranges": ["64520-64525"],
  "inside-cidr-blocks": ["10.255.0.0/16"],
  "edge-locations": [
    { "location": "us-east-1", "asn": 64520, "inside-cidr-blocks": ["10.255.0.0/24"] },
    { "location": "eu-west-1", "asn": 64521, "inside-cidr-blocks": ["10.255.1.0/24"] }
  ]
}
```

Two levels are at work here. The global `inside-cidr-blocks` is the **pool**, and a per-CNE `inside-cidr-blocks` says **which slice of that pool the CNE gets**.

The per-CNE keys are optional: leave them out and each CNE is auto-assigned a slice from the pool, so the example above simply pins what the service would otherwise pick. A `/24` is the smallest IPv4 slice and a `/64` the smallest IPv6 one.

The pool itself can be a single supernet, as above, or a list of `/24`s. That choice decides what happens when you add a Region later:

* **A supernet with headroom.** A new CNE is auto-assigned a block from the spare space, so adding a Region needs no edit here. If the pool has no room left for a `/24` or `/64`, the policy raises an exception instead.
* **A pool that exactly matches the per-CNE blocks.** The service reads that as a signal that no carving is needed and stops attempting it, which is fully deterministic — but every new Region then needs its own block added by hand.

Choose a range that overlaps nothing routable in your network, and size it before you deploy: an inside CIDR block cannot be deleted once assigned to a CNE. If you are not using Connect at all, leave the key out — setting it is what arms auto-assignment, so declaring a range you do not need only adds a way to fail later.

### `edge-locations`

The list of Regions, and so the list of CNEs. Each entry creates one, and `location` is its only unique field: `asn` comes out of [`asn-ranges`](#asn-ranges) and `inside-cidr-blocks` is a slice of the [pool](#inside-cidr-blocks), both covered above.

```json
{
  "edge-locations": [
    { "location": "us-east-1", "asn": 64520 },
    { "location": "eu-west-1", "asn": 64521 }
  ]
}
```

What matters here is what happens when the list changes:

* **Adding a Region.** Add the entry and the rest follows: segments are global, so every existing segment becomes available there and every existing attachment policy applies to attachments created in it. Give the new CNE an ASN out of `asn-ranges`, and if you use Connect, check the pool has a slice left.
* **Removing a Region.** A Region cannot be removed while attachments still use it. Delete every attachment on that CNE first, then take the entry out of the policy.

You get exactly one CNE per Region per core network, and that is not adjustable — which matters less than it sounds, because throughput is a property of the **attachment**, not the CNE. See [bandwidth quotas](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html). A CNE does bill [per hour](https://aws.amazon.com/cloud-wan/pricing/) from the moment the policy declares it, attached or not, so declare only the Regions you will attach to: undoing a speculative one means the cleanup above.

### `multipath-resilience`

[Multipath resilience](https://docs.aws.amazon.com/network-manager/latest/cloudwan/enable-multipath-resilience-cloudwan.html) replicates packets over several paths on the AWS backbone between Region pairs, which is how AWS Cloud WAN can achieve a [99.999% daily uptime SLA](https://aws.amazon.com/vpc/features/vpc-multipath-resilience/sla) for that traffic. To decide whether your workloads need it, see the [multipath resilience feature page](https://aws.amazon.com/vpc/features/vpc-multipath-resilience/).

> [!IMPORTANT]
> **Every Region pair it covers costs extra.** You pay a [per-GB charge on data sent between CNEs in different Regions](https://aws.amazon.com/cloud-wan/pricing/), on top of Cloud WAN data processing and inter-Region data transfer; data received is not charged. Use `edge-sets` to limit it to the pairs that need the SLA.

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `mode` | `best-effort` turns it on, `disabled` turns it off | Yes, if the block is present | Off: leaving the block out is the same as `disabled` |
| `edge-sets` | Limits it to the Region pairs listed. Each set names two Regions in `edge-locations`, in either order, and covers both directions. Both must be declared in [`edge-locations`](#edge-locations) and be supported, or the policy version fails validation | No | Every supported pair |

`best-effort` is about coverage, not delivery. Multipath resilience only works between supported Regions ([current list](https://docs.aws.amazon.com/network-manager/latest/cloudwan/enable-multipath-resilience-cloudwan.html)). `best-effort` turns it on for every pair of CNEs whose two Regions are supported, or only for the pairs in `edge-sets`, and leaves every other pair as it is: no replication, no SLA, no extra charge. A covered pair gets the full SLA.

**Cover every supported pair.** Every pair of these CNEs whose two Regions are supported is covered; a pair with an unsupported Region is skipped:

```json
{
  "edge-locations": [
    { "location": "us-east-1" },
    { "location": "us-west-2" },
    { "location": "eu-west-1" }
  ],
  "multipath-resilience": {
    "mode": "best-effort"
  }
}
```

**Cover only the pairs you list.** Only `us-east-1`–`eu-west-1` and `us-west-2`–`eu-west-1` are covered, and `us-east-1`–`us-west-2` stays uncovered:

```json
{
  "edge-locations": [
    { "location": "us-east-1" },
    { "location": "us-west-2" },
    { "location": "eu-west-1" }
  ],
  "multipath-resilience": {
    "mode": "best-effort",
    "edge-sets": [
      { "edge-locations": ["us-east-1", "eu-west-1"] },
      { "edge-locations": ["us-west-2", "eu-west-1"] }
    ]
  }
}
```

To check it, the console shows status and covered sets per policy version (**Policy versions**, then **Policy details**, **Network configuration**, **Multipath resilience**), and the [multipath resilience metrics](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-metrics.html#cloudwan-metrics-multipath-resilience) in the `AWS/Network Manager` namespace report each edge set per direction, with `MultipathResilienceSLANonCompliantSecondsToPeer` tracking the SLA.

### `vpn-ecmp-support`

Whether the core network load-shares traffic across multiple equal-cost paths [using VPN](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html). Defaults to `true`:

```json
{ "vpn-ecmp-support": true }
```

Configured as `true`, several tunnels advertising the same prefix carry traffic together, which is how VPN bandwidth grows past a single tunnel. Configured as `false`, the core network picks one path by internal metric. Either way it reaches only [VPN connections that use dynamic routing](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html) — a static-routed VPN cannot ECMP at all.

### `dns-support`

Whether a **public EC2 hostname resolves to a private address** across attached VPCs. Defaults to `true`, and the setting applies to every CNE in the core network:

```json
{ "dns-support": true }
```

Configured as `true`, querying another instance's public hostname returns its private address, so the traffic crosses the core network. Configured as `false`, it returns the public address.

It works [only between VPCs attached to the same CNE](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-vpc-attachment.html), never across Regions or across different CNEs.

**It is not how you get private DNS names across VPCs.** This key only changes what a *public* EC2 hostname resolves to. To resolve your own domain names in several VPCs, associate a [Route 53 private hosted zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html) with each of them. That is a Route 53 mechanism, independent of AWS Cloud WAN and unaffected by this key — and unlike `dns-support` it works across Regions.

### `security-group-referencing-support`

Whether an **inbound** security group rule in one VPC may reference a security group in another, instead of hard-coding CIDRs. The only switch here that defaults to `false`:

```json
{ "security-group-referencing-support": true }
```

Configured as `true`, your rules describe intent — "allow the app tier" rather than "allow 10.0.4.0/24" — which is what keeps a many-VPC estate maintainable as instances come and go. Three things to know before you rely on it:

* **Both levels have to be enabled.** This key covers the core network; each VPC attachment has its own setting, `true` by default. Referencing works only when [both levels are enabled](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-vpc-attachment.html), so setting it here is usually enough — but an attachment that explicitly disables it will not participate.
* **It is regional.** Only VPCs on the **same CNE** can reference each other, never across Regions or CNEs.
* **It is inbound only.** [Referencing is a matching criterion in inbound rules](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-vpc-attachment.html); egress rules still need CIDRs or prefix lists.
