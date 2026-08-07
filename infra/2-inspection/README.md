# Infra pattern 2 — Inspection

Adds **inspection VPCs with AWS Network Firewall** to [`1-basic`](../1-basic/), attached to a Cloud WAN **network function group** instead of a segment. This is the simplest place to learn service insertion.

<!-- DIAGRAM PLACEHOLDER -->
> _Architecture diagram to be added._

## Implementations

| IaC | Directory | Notes |
|-----|-----------|-------|
| Terraform | [`terraform/`](./terraform/) | One `apply` |
| CloudFormation | [`cloudformation/`](./cloudformation/) | **Three phases** — a service-insertion action cannot reference a network function group that has no attachments yet |

New to the repository? Read [`../README.md`](../README.md) first — it covers prerequisites, cost, the tagging contract, and how to deploy a pattern with your own policy instead of its baseline.

## What gets deployed

| Component | Configuration |
|-----------|---------------|
| AWS Regions | `us-east-1`, `eu-west-1` |
| Core network | One, with a Core Network Edge in each Region |
| Spoke VPCs | Two per Region — `prod`, `dev` |
| Inspection VPC | One per Region — public subnets, NAT gateway, internet gateway, firewall subnets. CIDR `10.100.0.0/16` |
| AWS Network Firewall | One per inspection VPC, with an endpoint per Availability Zone |
| Compute | An EC2 instance in every configured Availability Zone of each spoke VPC, plus an EC2 Instance Connect endpoint |

**Attachment types created:** `vpc` — both the spoke VPCs and the inspection VPCs. An inspection VPC is an ordinary `vpc` attachment; what makes it different is that it joins a network function group rather than a segment.

**Appliance mode is enabled** on the inspection VPC attachments, and inspection depends on it — without it the return path of a flow can land on a firewall endpoint holding no state for that flow, which drops it. The symptom is characteristically confusing: ICMP works, TCP hangs, and it appears to depend on which instance you test from. See [`policy/5-service_insertion.md`](../../policy/5-service_insertion.md#appliance-mode).

## Attachment tags applied

| VPC | Tag on its Cloud WAN attachment | Result |
|-----|---------------------------------|--------|
| `prod` | `domain = production` | Joins the `production` segment |
| `dev` | `domain = development` | Joins the `development` segment |
| Inspection VPC | `inspection = true` | Joins the `inspectionVpcs` network function group |

An inspection VPC is still a `vpc`, so attachment-type matching cannot distinguish it from a spoke — hence the `inspection` role tag. The rule that claims it must have a **lower rule number** than the `domain` rule: an attachment joins a segment *or* a network function group, never both, and the first matching rule wins. See [`policy/3-attachment_policies.md`](../../policy/3-attachment_policies.md).

## What the baseline policy demonstrates

[`baseline.json`](./baseline.json) shows both directions of service insertion in one document.

| Action | Segment | Effect |
|--------|---------|--------|
| `send-to` | `production` | Egress (internet-bound) traffic is inspected |
| `send-to` | `development` | Egress traffic is inspected |
| `send-via` `dual-hop` | `production` | Traffic to any segment, including itself, is inspected |

`production` is `isolate-attachments: true`, and that is **required**, not stylistic. Without isolation Cloud WAN has a direct route between the two production VPCs and uses it — traffic never reaches the firewall and the `send-via` action appears to do nothing at all. `tools/validate_policy.py` treats missing isolation as an error (`cwan-8`) precisely because the failure is invisible at runtime.

Resulting behaviour:

| Source | Destination | Result | Inspected |
|--------|-------------|--------|-----------|
| `prod` | Internet | Allowed to `*.amazon.com` only | Yes, by `send-to` |
| `dev` | Internet | Allowed to `*.amazon.com` only | Yes, by `send-to` |
| `prod` (us-east-1) | `prod` (eu-west-1) | Allowed | Yes, in **both** Regions — `dual-hop` |
| `prod` | `dev` (same Region) | Allowed | Yes, by `send-via` |
| `prod` (us-east-1) | `dev` (eu-west-1) | Allowed | Yes, in both Regions |
| `dev` (us-east-1) | `dev` (eu-west-1) | Allowed | **No** — `development` is not isolated and has no `send-via` |

`development` gets egress inspection but not east-west inspection — a common production posture, and the entire difference is the presence of a `send-via` action.

`dual-hop` inspects cross-Region traffic in both Regions, so each Region's firewall sees its own traffic, and it requires an inspection attachment in every participating Region — which this pattern provides. With only two Regions there is a single Region pair, so `dual-hop` and `single-hop` look almost identical in practice; [`policy/5-service_insertion.md`](../../policy/5-service_insertion.md#dual-hop-versus-single-hop) shows a four-Region matrix and what you would extend to see the difference.

## The bundled firewall policy

[`../tf_modules/firewall_policy`](../tf_modules/firewall_policy/) allows HTTPS to `*.amazon.com` and drops everything else on egress, and alerts-and-allows ICMP east-west.

That is enough to prove traffic is traversing the firewall: `curl https://www.amazon.com` succeeds and any other host fails. It is not a starting point for production rules — it exercises the Cloud WAN routing path, and says nothing about how to write firewall rules.

## Optional: secondary CIDR blocks

`create_secondary_cidrs = true` adds a secondary IPv4 CIDR block, with its own subnets, to each spoke VPC — `100.64.0.0/16` in `us-east-1` and `100.65.0.0/16` in `eu-west-1`.

It is off by default: it costs extra subnets, and the baseline policy does not filter the range, so it would propagate. Turn it on to work through [`policy/examples/filter_then_inspect.json`](../../policy/examples/filter_then_inspect.json), which needs a prefix its routing policy actually drops:

```bash
cd infra/2-inspection/terraform
terraform apply -var create_secondary_cidrs=true -var policy_document=../../../policy/examples/filter_then_inspect.json
```

The secondary ranges sit **outside** `10.0.0.0/8`, so an "allow `10.0.0.0/8`, drop everything else" policy drops them and leaves the spoke and inspection VPC prefixes intact. The inspection VPCs use `10.100.0.0/16` for the same reason.

## What this pattern can and cannot exercise

Policies that work here need **VPC attachments plus a network function group**: any combination of segmentation, sharing, egress inspection, east-west inspection, and inbound route filtering. Route summarization and BGP path preferences need a BGP-capable attachment, so those need [`3-transit_gateway`](../3-transit_gateway/) or [`4-hybrid`](../4-hybrid/). See the testability matrix in [`policy/README.md`](../../policy/README.md).

## Verifying it works

1. In Network Manager, confirm the inspection VPC attachments show the `inspectionVpcs` network function group, and the spoke attachments show their segments.
2. Connect to a spoke instance with EC2 Instance Connect.
3. **Egress:** `curl https://www.amazon.com` succeeds and `curl https://www.example.com` fails. Both appear in the firewall logs.
4. **East-west:** `ping` a production instance in the other Region. It succeeds, and the firewall logs an alert in *both* Regions — that is `dual-hop`.
5. `ping` between the two development instances. It succeeds and appears in **no** firewall log, because `development` has no `send-via`.

If east-west traffic works but never appears in a firewall log, check that `production` is isolated in the deployed policy. That is the single most common cause.

## Cost

**This is the most expensive pattern in the repository.**

| Resource | Count | Charged |
|----------|-------|---------|
| AWS Network Firewall | 2, one per inspection VPC, with an endpoint per Availability Zone | Hourly per endpoint, plus data processed |
| NAT gateway | 2, one per inspection VPC | Hourly, plus data processed |
| Core Network Edge | 2, one per Region | Hourly |
| VPC attachment | 6 — four spoke, two inspection | Hourly, per attachment |
| EC2 instance | One per configured Availability Zone of every spoke VPC | Hourly |
| EC2 Instance Connect endpoint | 4, one per spoke VPC | Hourly |

Network Firewall and the NAT gateways dominate, and both charge for data processed as well as uptime, so cost scales with how much you test. `create_secondary_cidrs = true` adds subnets but no chargeable resources.

Use a non-production account and run the cleanup steps in the IaC README when you are finished.
