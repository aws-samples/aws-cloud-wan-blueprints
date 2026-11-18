---
title: "Connect overlapping CIDRs through Cloud WAN with 1:1 NAT on attachments"
description: "A deployable CloudFormation and Terraform pattern with two VPCs that share 10.10.0.0/16 in different Regions, each translated to its own NAT CIDR on its VPC attachment, plus an optional BGP Site-to-Site VPN with the same overlap. Shows that NAT lives on the attachment rather than in the policy, how the NAT routes appear, and what each side sees."
---

# Infrastructure-as-Code Patterns — 1:1 NAT on AWS Cloud WAN attachments

In this pattern, we want to show how [1:1 NAT](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-nat.html) on Cloud WAN attachments connects networks whose CIDRs overlap. Unique addressing remains the design to aim for: use NAT for networks you cannot renumber, such as an acquisition or a partner, not as the default.

## Implementations

| IaC | Directory |
|-----|-----------|
| Terraform | [`terraform/`](./terraform/) |
| CloudFormation | [`cloudformation/`](./cloudformation/) |

> New to the repository? Read [`../README.md`](../README.md) first.

## What gets deployed

| Component | Configuration |
|-----------|---------------|
| AWS Regions | `us-east-1`, `eu-west-1` |
| AWS Cloud WAN resources | Global network & core network, with the Core Network Edge ASNs pinned to `64520` and `64521` |
| VPCs | `shared` (`10.0.0.0/16`, `us-east-1`, no NAT); `acquired-a` (`10.10.0.0/16`, `us-east-1`, NAT to `100.64.0.0/16`); `acquired-b` (`10.10.0.0/16`, `eu-west-1`, NAT to `100.65.0.0/16`) |
| Site-to-Site VPN | Optional, in `us-east-1`, BGP-routed — a customer gateway, a VPN connection, and its Cloud WAN attachment, with on-premises `10.10.0.0/16` translated to `100.66.0.0/16` |

**Attachment types created:** `vpc`, plus `site-to-site-vpn` when you enable it.

| Attachment | Tag | NAT rule (rule number, match source CIDR, NAT CIDR) |
|------------|-----|-----------------------------------------------------|
| `shared` | `domain = shared` | none |
| `acquired-a` | `domain = corporate` | `100`, `10.10.0.0/16`, `100.64.0.0/16` |
| `acquired-b` | `domain = corporate` | `100`, `10.10.0.0/16`, `100.65.0.0/16` |
| VPN | none, associated to `hybrid` by attachment type | `100`, `10.10.0.0/16`, `100.66.0.0/16`, with NAT system route support on |

All overlapping networks are translated, each to its own NAT CIDR. Translating only one side does not work when the CIDRs are identical: the untranslated VPC would deliver replies to its own CIDR locally.

## What the baseline policy configures

**NAT is not in the policy.** It is configured on each attachment (`NatGatewaySupport` and `NatGatewayRules`), and only the core network owner can configure it. [`baseline.json`](./baseline.json) is an ordinary three-segment policy:

| | |
|---|---|
| Segments | `corporate` (the acquired VPCs), non-isolated; `shared` (shared services), with `isolate-attachments`; `hybrid` (on-premises), non-isolated |
| Segment actions | `corporate` shares its routes with `shared` and `hybrid` (`attachment-route` mode). Sharing is not transitive, so `shared` and `hybrid` do not reach each other |
| Association | Rule 100 matches `attachment-type = vpc` **and** `tag-exists: domain`, then associates by the tag's value; rule 200 matches `site-to-site-vpn` and associates to `hybrid` by constant |
| Static routes | None. Each VPC rule matches its VPC CIDR exactly, so Cloud WAN replaces that VPC CIDR route with a `SYSTEM` route to the NAT CIDR. A rule that matches only part of a VPC CIDR needs a static route instead — see [`policy/6-static_routes.md`](../../policy/6-static_routes.md) |

Resulting reachability:

| Source | Destination | Result | What the destination sees |
|--------|-------------|--------|---------------------------|
| `shared` | `acquired-a` at `100.64.x.x` | Allowed | Source unchanged, `10.0.x.x` |
| `shared` | `acquired-b` at `100.65.x.x` | Allowed, cross-Region | Source unchanged, `10.0.x.x` |
| `acquired-a` | `acquired-b` at `100.65.x.x` | Allowed | Source `100.64.x.x` |
| `acquired-a` | `shared` at `10.0.x.x` | Allowed | Source `100.64.x.x` |
| on-premises | `acquired-a` at `100.64.x.x` | Allowed (VPN on) | Source `100.66.x.x` |
| `shared` | on-premises at `100.66.x.x` | No route | `shared` and `hybrid` each share routes with `corporate` only |

Translation is stateless and keeps the host bits: `10.10.0.37` in `acquired-a` is `100.64.0.37` to everyone else, and either side can start a connection.

## Verifying it works

1. In the AWS Network Manager console, confirm the three VPC attachments are `AVAILABLE`: `acquired-a` and `acquired-b` associated with `corporate`, `shared` with `shared`.
2. Check the segment route tables; they are the easiest place to confirm NAT is working, because describing an attachment does not show its NAT rules. Expect:
   - Each NAT CIDR as a `SYSTEM` route at its own edge and as `PROPAGATED` at the other edge: `100.64.0.0/16` from `us-east-1`, `100.65.0.0/16` from `eu-west-1`.
   - No `10.10.0.0/16` route in any segment.
   - `shared`'s `10.0.0.0/16` in `corporate` only. `shared` holds just the two NAT CIDRs.

   ```bash
   aws networkmanager get-network-routes --global-network-id <global-network-id> --route-table-identifier '{"CoreNetworkSegmentEdge":{"CoreNetworkId":"<core-network-id>","SegmentName":"corporate","EdgeLocation":"us-east-1"}}' --region us-west-2
   ```

3. Connect to an instance in `acquired-b` with EC2 Instance Connect and run `sudo tcpdump -ni any icmp`. From an instance in `acquired-a`, `ping` the `acquired-b` instance at its `100.65.x.x` address. The capture shows the source as `100.64.x.x`. From `shared`, the same ping arrives from its real `10.0.x.x` address.

> **Deployed a policy of your own?** Step 1 still applies. Steps 2 and 3 describe the baseline: a NAT CIDR only reaches the segments your policy shares it with, and a routing policy that filters prefixes can remove it.

### Hybrid attachments

Direct Connect gateway and BGP Site-to-Site VPN attachments handle NAT the same way, so this applies to both. This pattern uses a VPN as the example, with on-premises `10.10.0.0/16` translated to `100.66.0.0/16`. A statically routed VPN and a Connect attachment work differently: see [Routing behavior for 1:1 NAT](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-nat-routing.html).

> **The default VPN values do not bring the tunnels up.** The customer gateway IP in the examples, `203.0.113.10`, is a documentation address, so the tunnels stay down and the `SYSTEM` route for `100.66.0.0/16` shows as `BLACKHOLE` in `hybrid` and `corporate` at `us-east-1`. That still shows the VPN attachment associated with `hybrid` and its NAT route installed. To test reachability end to end, set the customer gateway IP and ASN to a device in your own on-premises or lab network that advertises `10.10.0.0/16` over BGP.

Each hybrid attachment chooses how the NAT CIDR gets into the segment:

- **Cloud WAN installs the route (NAT system route support on, the default and what this pattern uses):** a `SYSTEM` route for the NAT CIDR, forwarded along the routes on-premises advertises that overlap the original CIDR. On-premises must still advertise `10.10.0.0/16`; if it advertises nothing that overlaps it, the NAT route drops traffic.
- **You advertise it (off):** your routers advertise `100.66.0.0/16`, with the AS path, MED or communities you need for path selection.

In both modes Cloud WAN keeps the original routes on-premises advertises, so `10.10.0.0/16` sits in `hybrid` and, through the share, in `corporate`. The acquired VPCs keep using their local route, but any other `corporate` attachment would reach on-premises untranslated. To prevent that, drop `10.10.0.0/16` with a routing policy on the share ([`4-segment_sharing.md`](../../policy/4-segment_sharing.md#routing-policy-names)), not on the attachment: the installed NAT route forwards along that original route, so filtering it at the attachment blackholes the NAT route.

In the other direction, on-premises learns the acquired VPCs' NAT CIDRs (`100.64.0.0/16`, `100.65.0.0/16`) with the core network ASN in the AS path, not their real `10.10.0.0/16`, and does not learn `shared`'s `10.0.0.0/16`.

## Limitations

- **Only the core network owner configures NAT.** In a multi-account setup like [`5-multi_account`](../5-multi_account/), the spoke account creates the attachment and the owner adds the rules. See [Permissions](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-nat-permissions.html).
- **Enabling NAT on a VPC attachment in use cuts off peers that reach it by its real addresses.** Move them to the NAT addresses first. See [Configuring 1:1 NAT](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-nat-configure.html).
- **Any NAT change can briefly drop traffic to the new NAT addresses.** Make changes in a maintenance window. See [Brief traffic loss during changes](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-nat-routing.html#cloudwan-nat-routing-traffic-loss).
- **NAT CIDRs must be unique across your whole network.** Cloud WAN checks overlap only between rules on the same attachment, so reserve a dedicated block (this pattern uses `100.64.0.0/10`) and give each network its own slice. See [Prerequisites](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-nat-how-it-works.html#cloudwan-nat-prerequisites).

For the rest, check the documentation: [supported attachment types](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-nat.html#cloudwan-nat-supported-attachments) (not Transit Gateway route table or Tunnel-less Connect attachments, nor a VPC attachment with appliance mode), [IPv4 only](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-nat.html#cloudwan-nat-key-properties), [rule limits and CIDR requirements](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-nat-configure.html), and [pricing](https://aws.amazon.com/cloud-wan/pricing/) (hourly per attachment plus per GB processed).

## Cost

| Resource | Count | Charged |
|----------|-------|---------|
| Core Network Edge | 2, one per Region | Hourly |
| VPC attachment | 3 | Hourly, per attachment |
| 1:1 NAT | 2 VPC attachments, plus the VPN attachment when enabled | Hourly, per attachment, plus data processed |
| Site-to-Site VPN connection | 0 or 1 | Hourly, plus data transferred |
| Site-to-Site VPN attachment | 0 or 1 | Hourly, per attachment |
| EC2 instance | One per configured Availability Zone of every VPC | Hourly |
| EC2 Instance Connect endpoint | 3, one per VPC | Hourly |

Use a non-production account and run the cleanup steps in the IaC README when you are finished.
