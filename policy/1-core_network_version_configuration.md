# Core network policy version and core network configuration

Before AWS Cloud WAN can route anything, it needs a presence in every AWS Region you operate in, and that presence needs a BGP identity. That is what this part of the policy decides. You name the Regions, and AWS Cloud WAN builds a **Core Network Edge (CNE)** in each one: a managed, highly available regional hub that your attachments connect to. Every CNE is automatically peered with every other and they exchange routes over [external BGP](https://aws.amazon.com/what-is/border-gateway-protocol/) (eBGP), so you never create a peering or write a route between Regions.

Everything else you will write sits on top of that. Segments only exist where there is a CNE, and attachments can only be created where their segment exists. So this is the first block you write, and it decides the shape of the rest.

It is also the block that is hardest to walk back. Most of an AWS Cloud WAN policy is an in-place edit — you can add a segment, change what is shared, or move where inspection happens on a running network. However **a Region cannot be removed while attachments still use it** and **a CNE's ASN cannot be changed at all** once assigned. Both are worth a few minutes of planning before your first deploy, which is what [`asn-ranges`](#asn-ranges) and [`edge-locations`](#edge-locations) below cover.

In the JSON this is two top-level keys, [**`version`**](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html#cloudwan-version-json) and [**`core-network-configuration`**](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html#cloudwan-network-config-json):

## `version`

A required top-level key. There are exactly two accepted values, and the choice is a capability gate, not a format marker:

| Version | Supports |
|---------|----------|
| `2021.12` | Segments, segment sharing, attachment policies, service insertion |
| `2025.11` | All of the above, **plus routing policies and BGP community propagation** |

```json
{ "version": "2025.11" }
```

`2025.11` also changes behaviour, not only what you are allowed to write. Community tags arriving from BGP-capable attachments propagate across the core network, where on `2021.12` they are discarded — and as they cross, the **subtype of a community tag is dropped**, while tags propagated **outbound** have theirs **set to Route Target**. So if anything on-premises matches on community subtypes, check it before you rely on this.

Use `2025.11` either way. Starting from scratch, it is a strict superset of `2021.12` and the only version with the full set of AWS Cloud WAN capabilities, so beginning on `2021.12` buys nothing and costs you a migration later. Already running `2021.12`, upgrade: the propagation change above is the only thing to plan for, and it is usually much of the reason to upgrade in the first place.

## `core-network-configuration`

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `asn-ranges` | The pool CNE ASNs are drawn from | Yes | — |
| `inside-cidr-blocks` | Tunnel addressing for Connect attachments | No | Not set — omit unless you use Connect |
| `edge-locations` | One CNE per Region listed | Yes | — |
| `edge-locations[].location` | The Region code, such as `us-east-1` | Yes | — |
| `edge-locations[].asn` | Pins that CNE's ASN instead of letting the service choose | No | Auto-assigned from `asn-ranges` |
| `edge-locations[].inside-cidr-blocks` | That CNE's Connect tunnel addressing | No | Auto-assigned from the global `inside-cidr-blocks` |
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
