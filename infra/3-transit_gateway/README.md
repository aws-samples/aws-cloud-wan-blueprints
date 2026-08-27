---
title: "Connect AWS Transit Gateway to Cloud WAN: peering and route table attachments"
description: "A deployable CloudFormation and Terraform pattern peering a Transit Gateway in each Region with a Cloud WAN core network, then binding its route tables to segments — the coexistence and migration path for an existing Transit Gateway network. Shows how intra-Region separation comes from Transit Gateway route tables while cross-Region separation comes from Cloud WAN segments."
---

# Infrastructure-as-Code Patterns — AWS Cloud WAN with AWS Transit Gateway

In this pattern, we want to show how AWS Cloud WAN connects to AWS Transit Gateway using a peering connection - and how segmentation can be configured on top of that peering. Users can test global traffic segmentation, communication between segments, and segment isolation for workloads that reach the core network through a Transit Gateway.

![Transit Gateway peering architecture](../../images/3-transit_gateway.png)

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
| AWS Cloud WAN resources | Global network & core network |
| Transit Gateway | One per Region, ASN `64532` and `64533`, with default route table association and propagation disabled |
| Transit Gateway route tables | Two per Region — `production`, `development` |
| Cloud WAN peering | One per Region, between the Transit Gateway and the core network, with a Transit Gateway policy table associated with it |
| Spoke VPCs | Two per Region — `prod`, `dev` — each with three subnet tiers, one of them for the Transit Gateway attachment |
| Compute | An EC2 instance in every configured Availability Zone of each spoke VPC, plus an EC2 Instance Connect endpoint per VPC |

**Attachment types created:** `transit-gateway-route-table` only. The spoke VPCs are **not** Cloud WAN attachments — they attach to the Transit Gateway, and each Transit Gateway route table attaches to Cloud WAN.

Each attachment is tagged, and those tags are all a policy has to match on:

| Attachment | Tag on its Cloud WAN attachment |
|------------|---------------------------------|
| `production` route table | `domain = production` |
| `development` route table | `domain = development` |

The Transit Gateway ASNs must not overlap the core network's `asn-ranges`, which the baseline sets to `64520-64525` with the Core Network Edge ASNs pinned to `64520` and `64521`.

## What the baseline policy configures

[`baseline.json`](./baseline.json) is the minimum that binds Transit Gateway route tables to segments, and nothing else.

| | |
|---|---|
| Segments | `production` and `development`, both non-isolated |
| Association | Rule 100 matches `attachment-type = transit-gateway-route-table` **and** `tag-exists: domain`, then associates by the tag's value |
| Sharing | None declared, so the two segments cannot reach each other |

Association is by **tag value**, so one attachment-policy rule handles both segments. Any policy you deploy here must match the `domain` tag, or the route tables will attach and never associate.

Resulting reachability:

| Source | Destination | Result | Why |
|--------|-------------|--------|-----|
| `prod` (us-east-1) | `prod` (eu-west-1) | Allowed | Both route tables land in `production`, and segments are global |
| `dev` (us-east-1) | `dev` (eu-west-1) | Allowed | Same, via `development` |
| `prod` | `dev` (same Region) | Blocked | Different Transit Gateway route tables, so the Transit Gateway has no route between them |
| `prod` | `dev` (cross-Region) | Blocked | No sharing declared between the segments |

Two layers are doing the work: separation within a Region comes from the Transit Gateway route tables, separation across Regions comes from the Cloud WAN segments.

## Verifying it works

1. In the AWS Network Manager console, confirm the four `transit-gateway-route-table` attachments — two per Region — are `AVAILABLE` **and** associated with the segment matching its `domain` tag.
2. In the Transit Gateway console, confirm each spoke VPC attachment is associated with the expected route table and propagating into it.
3. Connect to an instance with EC2 Instance Connect — the endpoint sits in each VPC's endpoints subnet.
4. Work through the reachability table above with `ping`. The security groups allow ICMP.

> **Deployed a policy of your own?** Steps 1 to 3 still apply — every attachment has to be `AVAILABLE` and associated where you expect. Step 4 does not: that table describes the baseline, so derive your own expectations from the segments and `share` actions you wrote. Beyond reachability, what to check depends on the capabilities you used, and the [`policy/`](../../policy/) pages cover them.

If an attachment is `AVAILABLE` but shows no segment, the `domain` tag and the policy's attachment policies disagree — the most common Cloud WAN misconfiguration. See [`policy/3-attachment_policies.md`](../../policy/3-attachment_policies.md).

If cross-Region traffic fails while the attachments look correct, check that the Transit Gateway route table has a route for the remote prefix through the peering attachment.

## Cost

| Resource | Count | Charged |
|----------|-------|---------|
| Transit Gateway | 2, one per Region | Hourly per attachment, plus data processed |
| Transit Gateway VPC attachment | 4, two per Region | Hourly |
| Transit Gateway / Cloud WAN peering | 2, one per Region | Hourly |
| Core Network Edge | 2, one per Region | Hourly |
| EC2 instance | One per configured Availability Zone of every VPC | Hourly |
| EC2 Instance Connect endpoint | 4, one per VPC | Hourly |

Use a non-production account and run the cleanup steps in the IaC README when you are finished.
