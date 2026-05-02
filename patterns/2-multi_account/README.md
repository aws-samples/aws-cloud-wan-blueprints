# AWS Cloud WAN Blueprints - Multi-Account architecture

## Overview

This pattern demonstrates how AWS Cloud WAN operates in multi-account environments using [AWS Resource Access Manager](https://docs.aws.amazon.com/ram/latest/userguide/what-is.html) (RAM) to share the core network across accounts.

**Use this pattern to**:

- Understand multi-account Cloud WAN deployments.
- Learn how to share core networks using AWS RAM.
- Implement centralized network management with distributed workloads.
- Build a foundation for enterprise-scale architectures.

> **Note**: This pattern demonstrates cross-account sharing and does not include service insertion (traffic inspection) or routing policies. For inspection architectures, see the [Traffic Inspection Patterns](../3-traffic_inspection/) section. For routing policies, see the [Routing policies](../4-routing_policies/) section.

## Architecture

### What gets deployed

| Component | Configuration |
|-----------|---------------|
| **AWS Accounts** | Networking Account, Spoke Account |
| **AWS Regions** | us-east-1, eu-west-1 |
| **Segments** | `production`, `development` |
| **VPCs** | Multiple VPCs in Spoke Account |
| **RAM Sharing** | Core Network shared from Networking to Spoke Account |
| **Segment Isolation** | `production` segment is isolated |

---

![Multi-Account Architecture](../../images/patterns_multi_account.png)

### Account structure

#### Networking Account

The central account that owns and manages the Cloud WAN infrastructure:

| Resource | Purpose |
|----------|---------|
| **Global Network** | Container for the core network |
| **Core Network** | Global network infrastructure with policy |
| **Network Policy** | Defines segments, attachment policies, and routing |
| **RAM Resource Share** | Shares core network with spoke account(s) |

> **Important**: Core network sharing must be done from the us-east-1 region. See [AWS documentation](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-share-network.html) for details.

#### Spoke Account

Any account that connects workloads to the shared Cloud WAN:

| Resource | Purpose |
|----------|---------|
| **VPCs** | Workload VPCs across regions |
| **Cloud WAN Attachments** | Connect VPCs to shared core network |
| **EC2 Instances** | Compute resources for testing |
| **EC2 Instance Connect Endpoints** | Secure access to instances |
| **RAM Share Acceptance** | Accept core network share (if accounts are not in the same AWS Organization) |

### Segment Configuration

| Segment | Isolation | Intra-Segment Communication |
|---------|-----------|----------------------------|
| **production** | ✅ Isolated | ❌ Blocked (isolated) |
| **development** | ❌ Not Isolated | ✅ Allowed |

### Attachment policy logic

The network policy includes one attachment policy rule that determines segment association for spoke account attachments:

#### Rule 100

```
IF account_id == "<spoke-account-id>" 
   AND attachment_type == "vpc" 
   AND tag "domain" exists
THEN associate to segment matching the "domain" tag value
```

**Example**:

- VPC in spoke account tagged with `domain=production` → Associates to `production` segment
- VPC in spoke account tagged with `domain=development` → Associates to `development` segment

**Key Feature**: The `account-id` condition ensures only attachments from the authorized spoke account are automatically associated.

### Traffic Flow Examples

| Source | Destination | Result | Reason |
|--------|-------------|--------|--------|
| Production VPC A (Spoke) | Production VPC B (Spoke) | ❌ Blocked | `production` segment is isolated |
| Development VPC A (Spoke) | Development VPC B (Spoke) | ✅ Allowed | `development` segment allows intra-segment traffic |
| Production VPC (Spoke) | Development VPC (Spoke) | ❌ Blocked | No segment sharing between `production` and `development` |

## Network Policy

```json
{
  "version": "2025.11",
  "core-network-configuration": {
    "vpn-ecmp-support": false,
    "asn-ranges": [
      "64520-64525"
    ],
    "edge-locations": [
      {
        "location": "eu-west-1"
      },
      {
        "location": "us-east-1"
      }
    ]
  },
  "segments": [
    {
      "isolate-attachments": true,
      "name": "production",
      "require-attachment-acceptance": false
    },
    {
      "name": "development",
      "require-attachment-acceptance": false
    }
  ],
  "attachment-policies": [
    {
      "rule-number": 100,
      "condition-logic": "and",
      "action": {
        "association-method": "tag",
        "tag-value-of-key": "domain"
      },
      "conditions": [
        {
          "type": "tag-exists",
          "key": "domain"
        },
        {
          "type": "attachment-type",
          "value": "vpc",
          "operator": "equals"
        },
        {
          "type": "account-id",
          "value": "<spoke-account-id>",
          "operator": "equals"
        }
      ]
    }
  ]
}
```

## Implementation

| IaC Tool | Location | Documentation |
|----------|----------|---------------|
| **CloudFormation** | [`./cloudformation/`](./cloudformation/) | [CloudFormation README](./cloudformation/README.md) |
| **Terraform** | [`./terraform/`](./terraform/) | [Terraform README](./terraform/README.md) |

### Deployment Order

1. **Networking Account**: Deploy core network and RAM share
2. **Spoke Account**: Accept RAM share (if accounts are not in the same AWS Organization) and deploy VPCs and attachments

## Testing Connectivity

After deployment, test connectivity between VPCs in the spoke account:

### 1. Verify RAM Share Status

**In Networking Account**:

```bash
aws ram get-resource-shares \
  --resource-owner SELF \
  --region us-east-1
```

**In Spoke Account**:

```bash
aws ram get-resource-shares \
  --resource-owner OTHER-ACCOUNTS \
  --region us-east-1
```

> **Note**: If both accounts are in the same AWS Organization with RAM sharing enabled, the share is auto-accepted. Otherwise, the share invitation needs to be accepted before deploying workloads.

### 2. Verify Segment Associations

Check that VPCs are associated with the correct segments in the AWS Network Manager console (accessible from both accounts).

### 3. Test Intra-Segment Communication

**Development Instances** (should work):

```bash
# From Development VPC A, ping Development VPC B
ping <dev-vpc-b-instance-ip>
```

**Production Instances** (should fail):

```bash
# From Production VPC A, ping Production VPC B
ping <prod-vpc-b-instance-ip>
# Expected: Timeout (isolated segment)
```

### 4. Test Cross-Region Communication

**Same Segment, Different Regions** (should work):

```bash
# From Development VPC in us-east-1, ping Development VPC in eu-west-1
ping <dev-vpc-eu-west-1-instance-ip>
```

### 5. Test Cross-Segment Isolation

**Production to Development** (should fail):

```bash
# From Production VPC, ping Development VPC
ping <dev-vpc-instance-ip>
# Expected: Timeout (no segment sharing)
```

## Troubleshooting

### RAM Share not visible in Spoke Account

**Check**:

1. Share was created in us-east-1 region
2. Correct spoke account ID in share
3. Spoke account has accepted invitation (if required)
4. Check RAM share status in both accounts

### VPCs not associating to segments

**Check**:

1. RAM share is accepted and active
2. VPC has correct `domain` tag
3. Attachment policy includes spoke account ID
4. Cloud WAN attachment is in "Available" state
5. Policy is in "LIVE" state

### Cannot create attachments in Spoke Account

**Check**:

1. Core network is shared via RAM
2. RAM share is accepted
3. IAM permissions allow attachment creation
4. Core network ID is correct

### Cross-Account connectivity issues

**Check**:

1. VPC route tables in spoke account have routes to Cloud WAN
2. Security groups allow required traffic
3. Network ACLs are not blocking traffic
4. Both VPCs are in the same segment
5. Segment isolation settings match expectations

## Next Steps

After mastering this multi-account architecture, explore:

1. **[Traffic Inspection](../3-traffic_inspection/)** - Add centralized inspection across accounts
2. **[Routing Policies](../4-routing_policies/)** - Implement advanced routing controls
3. **Scale to Multiple Spoke Accounts** - Expand to enterprise-scale deployments
