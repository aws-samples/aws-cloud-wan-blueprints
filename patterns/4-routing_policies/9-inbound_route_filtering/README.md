# 9. Inbound Route Filtering with Prefix Lists

> **⚠️ Hybrid Environment Required**: This pattern requires you to establish hybrid connectivity (Direct Connect Gateway or Site-to-Site VPN) with BGP sessions advertising routes from on-premises. The IaC code creates the Cloud WAN infrastructure and prefix list, but you must configure your on-premises router to advertise routes for testing.

This pattern demonstrates how to **drop dangerous routes advertised from on-premises** before they enter your Cloud WAN segments. This is a day-1 security requirement for any hybrid deployment — without inbound filtering, on-premises can accidentally (or maliciously) advertise routes that overlap with your VPC CIDRs or attract all traffic via a default route.

## Problem

On-premises routers advertise routes via BGP over Direct Connect or VPN. Without filtering, these routes propagate into your Cloud WAN segments. Dangerous scenarios include:

| Advertised Route | Risk |
|---|---|
| `0.0.0.0/0` | Default route attracts ALL traffic to on-prem, blackholing cloud workloads |
| `10.0.0.0/16` | Overlaps with production VPC CIDR — causes routing conflicts |
| `10.0.0.0/8` | Supernet covers all VPCs — on-prem becomes preferred path for east-west traffic |

## Solution

Use a **routing policy** with `prefix-in-prefix-list` match condition to drop specific prefixes inbound from hybrid attachments before they enter the segment route table.

### Key Components

| Component | Configuration |
|-----------|---------------|
| **Regions** | us-east-1, eu-west-1 |
| **Segments** | `production`, `hybrid` |
| **Routing Policy** | `inboundDropDangerousRoutes` (direction: inbound) |
| **Match Condition** | `prefix-in-prefix-list` → `dangerousPrefixes` |
| **Action** | `drop` |
| **Policy Association** | Via routing-policy-label `hybridRouteFiltering` on DX attachment |

### How It Works

1. On-premises advertises routes via BGP: `192.168.0.0/24`, `10.0.0.0/16`, `0.0.0.0/0`
2. Cloud WAN receives routes on the hybrid segment attachment
3. **Before** routes enter the segment route table, the inbound routing policy evaluates them
4. Routes matching the prefix list (`0.0.0.0/0`, `10.0.0.0/16`, `10.0.0.0/8`) are **dropped**
5. Only safe routes (`192.168.0.0/24`) propagate into the hybrid segment
6. Safe routes are then shared with the production segment via segment-actions

### Traffic Flow

| Advertised from On-Prem | In Prefix List? | Result |
|---|---|---|
| `192.168.0.0/24` | ❌ No | ✅ Accepted into hybrid segment |
| `192.168.10.0/24` | ❌ No | ✅ Accepted into hybrid segment |
| `0.0.0.0/0` | ✅ Yes | ❌ **Dropped** (dangerous default route) |
| `10.0.0.0/16` | ✅ Yes | ❌ **Dropped** (overlaps with VPC CIDR) |
| `10.0.0.0/8` | ✅ Yes | ❌ **Dropped** (supernet covers all VPCs) |

## Implementation

| IaC Tool | Location |
|----------|----------|
| **CloudFormation** | [`./cloudformation/`](./cloudformation/) |
| **Terraform** | [`./terraform/`](./terraform/) |

### Post-Deployment Step (Required)

After deploying the infrastructure, you must associate the prefix list with the Core Network. This step is required because there is no native Terraform/CloudFormation resource for this operation yet:

```bash
aws networkmanager create-core-network-prefix-list-association \
  --core-network-id <core-network-id> \
  --prefix-list-arn <prefix-list-arn> \
  --prefix-list-alias "dangerousPrefixes" \
  --region us-east-1
```

For CloudFormation deployments, use `make associate-prefix-list` which handles this automatically.

## Verification

After deployment and prefix list association:

1. Advertise `192.168.0.0/24` from on-premises → should appear in hybrid segment routes
2. Advertise `0.0.0.0/0` from on-premises → should NOT appear in hybrid segment routes
3. Advertise `10.0.0.0/16` from on-premises → should NOT appear (overlaps with VPC)

Check routes:
```bash
aws networkmanager get-network-routes \
  --global-network-id <global-network-id> \
  --route-table-identifier '{"CoreNetworkSegmentEdge": {"CoreNetworkId": "<core-network-id>", "SegmentName": "hybrid", "EdgeLocation": "us-east-1"}}' \
  --region us-east-1
```

## Updating the Prefix List

To add or remove prefixes from the drop list, update the managed prefix list:

```bash
aws ec2 modify-managed-prefix-list \
  --prefix-list-id <prefix-list-id> \
  --add-entries '[{"Cidr": "172.16.0.0/12", "Description": "Block RFC1918 supernet"}]' \
  --current-version <current-version>
```

Changes take effect immediately — no policy redeployment needed.
