# Core Network Configuration

Produces the **`core-network-configuration`** block — the foundation every other part
of the policy sits on. It answers two questions: *in which Regions does my network have
a router*, and *what BGP identity do those routers use*.

Get this wrong and nothing else works, because segments only exist where there is a
Core Network Edge, and attachments can only be created where their segment exists.

```json
{
  "version": "2025.11",
  "core-network-configuration": {
    "vpn-ecmp-support": false,
    "dns-support": true,
    "security-group-referencing-support": false,
    "asn-ranges": ["64520-64525"],
    "edge-locations": [
      { "location": "us-east-1" },
      { "location": "eu-west-1" }
    ]
  }
}
```

## `version`

The policy document's schema version, and it is a **capability gate**, not just a
format marker:

| Version | Supports |
|---------|----------|
| `2021.12` | Segments, sharing, service insertion |
| `2025.11` | The above **plus routing policies and BGP community propagation** |

Every policy in this repository uses `2025.11`. If you are on `2021.12` and want
anything from [`6-routing_policies.md`](./6-routing_policies.md), upgrading the version
is the first step.

## `edge-locations` — where your routers are

Each entry creates one **Core Network Edge (CNE)**: a managed, highly available
regional router, conceptually equivalent to a Transit Gateway.

```json
{
  "edge-locations": [
    { "location": "us-east-1" },
    { "location": "eu-west-1" },
    { "location": "ap-southeast-2" }
  ]
}
```

Three things follow from this list, and they are the reason Cloud WAN differs from
Transit Gateway:

- **CNEs are automatically full-mesh peered** and exchange routes over **e-BGP**. You
  do not create peerings, and you do not write static routes between Regions.
- **Segments exist in every CNE Region** by default. Adding a Region to this list makes
  every existing segment available there, and every existing attachment policy applies
  to attachments created there. Expanding to a new Region is a *policy* change.
- **A CNE bills whether or not it carries traffic.** Do not list Regions
  speculatively — an unused edge location is a running cost with nothing attached to it.

Each CNE supports up to 100 Gbps. See the
[quotas](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html)
for current limits.

> **The Regions here must match the infrastructure you deploy.** Every
> [`infra/`](../infra/) pattern deploys `us-east-1` and `eu-west-1`, so a policy for
> those patterns declares exactly those two. `tools/validate_policy.py --infra` checks
> this, because a mismatch means either attachments with no CNE to attach to, or a CNE
> billing for nothing.

### Pinning an ASN per Region

By default Cloud WAN picks each CNE's ASN out of `asn-ranges`. You can pin it instead,
which you will want as soon as you write routing policies that match on AS_PATH, or
have on-premises routers whose configuration references specific peer ASNs:

```json
{
  "asn-ranges": ["65000-65010"],
  "edge-locations": [
    { "location": "us-east-1", "asn": 65000 },
    { "location": "eu-west-1", "asn": 65001 }
  ]
}
```

Pinning makes AS_PATH predictable, which in turn makes path-preference policies
readable. Compare `65000 → 65500, 65501, 65052` against the same path with
auto-assigned ASNs you have to look up.

## `asn-ranges` — the BGP identity of your network

An array of ranges from which CNE ASNs are drawn.

**Only two ranges are permitted:** `64512`–`65534` (16-bit private) and
`4200000000`–`4294967294` (32-bit private). Nothing else is accepted.

> **⚠️ The range is left-closed and right-open.** `"64900-64903"` yields
> **64900, 64901, 64902** — the upper bound is *excluded*. This surprises almost
> everyone the first time. Size your range with one more than you think you need: the
> repository's `"64520-64525"` provides five usable ASNs, not six.

Two collision rules matter, and both are enforced by `tools/validate_policy.py`:

1. **Do not overlap ASNs used by your on-premises network.** A CNE and an on-premises
   router sharing an ASN breaks e-BGP path selection in ways that look like random
   blackholing.
2. **Do not overlap ASNs used in routing policies.** ASNs you prepend, replace, or
   remove in a routing policy must fall *outside* `asn-ranges`. This is a hard Cloud WAN
   restriction, not a recommendation, and it is why path-preference examples use
   values like `65500`/`65501` while the core network sits in `65000`–`65010`
   (check `cwan-6`).

## `vpn-ecmp-support`

Whether the core network load-shares traffic across multiple equal-cost VPN paths.
**Defaults to `true`.**

```json
{ "vpn-ecmp-support": true }
```

Enable it when you have multiple VPN tunnels to the same destination and want the
aggregate throughput and faster failover. Be deliberate about it if you run stateful
appliances on-premises reached over several tunnels — ECMP can place the two directions
of a flow on different tunnels, and an appliance that expects to see both will drop the
traffic. That failure looks like an application bug, not a network one.

## `dns-support`

**Defaults to `true`.** Lets public EC2 DNS hostnames resolve to *private* IP addresses
when queried from another VPC attached to the same core network **in the same Region**.

```json
{ "dns-support": true }
```

Without it, an instance resolving another VPC's public EC2 hostname gets the public
address and the traffic tries to leave via the internet rather than crossing the core
network.

## `security-group-referencing-support`

**Defaults to `false`** — the one setting whose default you will most often want to
change.

```json
{ "security-group-referencing-support": true }
```

When enabled, a security group ingress rule in one VPC can reference a security group
in **another** VPC attached to the same core network, instead of hard-coding CIDR
ranges. That is the difference between security rules that describe *intent* ("allow
the app tier") and rules that describe *addresses* ("allow 10.0.4.0/24"), and it is what
makes a many-VPC estate maintainable.

**Scope limit:** referencing works within the **same Region and the same CNE**. It is
not a cross-Region mechanism, so a design that assumes global security group
referencing will not work.

## `inside-cidr-blocks`

Required only for **Connect attachments** (Transit Gateway Connect / SD-WAN). These
CIDRs are used for the GRE tunnel inside addresses between Cloud WAN and the appliance —
they are tunnel infrastructure, not workload addressing.

```json
{
  "inside-cidr-blocks": ["10.255.0.0/16"],
  "edge-locations": [
    { "location": "us-east-1", "inside-cidr-blocks": ["10.255.0.0/24"] },
    { "location": "eu-west-1", "inside-cidr-blocks": ["10.255.1.0/24"] }
  ]
}
```

You can declare a global block and optionally carve a per-edge-location subset, as
above. Choose a range that does not overlap anything routable in your network, and size
it for the number of Connect peers you expect. Omit this key entirely if you are not
using Connect — see [`infra/4-hybrid`](../infra/4-hybrid/).

## A complete configuration block

Everything above, for a two-Region network with pinned ASNs and Connect enabled:

```json
{
  "version": "2025.11",
  "core-network-configuration": {
    "vpn-ecmp-support": true,
    "dns-support": true,
    "security-group-referencing-support": true,
    "asn-ranges": ["65000-65010"],
    "inside-cidr-blocks": ["10.255.0.0/16"],
    "edge-locations": [
      { "location": "us-east-1", "asn": 65000 },
      { "location": "eu-west-1", "asn": 65001 }
    ]
  }
}
```

## Constraints to carry forward

| Constraint | Consequence |
|------------|-------------|
| ASN ranges are limited to `64512`–`65534` and `4200000000`–`4294967294` | Anything else is rejected |
| ASN ranges are **right-open** | `64900-64903` gives three ASNs, not four |
| Routing-policy ASNs must not overlap `asn-ranges` | Enforced by `cwan-6` |
| Edge locations must match your deployed Regions | Enforced by `cwan-14` with `--infra` |
| Security group referencing is same-Region, same-CNE | Not a cross-Region mechanism |
| The Cloud WAN control plane / home Region is `us-west-2` | Managed prefix lists for routing policies must be created there (`cwan-13`) |
| A CNE bills per hour regardless of traffic | Do not list Regions you are not using |

## Next

[`2-segments.md`](./2-segments.md) — the routing domains that live on top of these
edges.

## Reference

- [Core network policy parameters](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html)
- [Configure core network settings](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-core-network-config.html)
- [Security group referencing and DNS support](https://aws.amazon.com/blogs/networking-and-content-delivery/introducing-security-group-referencing-and-enhanced-dns-support-for-aws-cloud-wan/)
- [Quotas](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html)
