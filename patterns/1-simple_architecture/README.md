# AWS Cloud WAN Blueprints - Simple Architecture

## Overview

This pattern demonstrates the fundamental concepts of AWS Cloud WAN through a straightforward multi-region architecture. It's designed as an entry point for understanding segments, segment actions, and attachment policies.

**Use this pattern to**:

- Learn Cloud WAN basics in a hands-on environment.
- Understand segment isolation and sharing concepts.
- Test tag-based attachment association.
- Build a foundation for more complex patterns.

> **Note**: This pattern does not include service insertion (traffic inspection) or routing policies. For inspection architectures, see the [Traffic Inspection Patterns](../3-traffic_inspection/) section. For routing policies, see the [Routing policies](../4-routing_policies/) section.

## Architecture

### What gets deployed

| Component | Configuration |
|-----------|---------------|
| **AWS Regions** | us-east-1, eu-west-1 |
| **Segments** | `production`, `development`, `shared` |
| **VPCs** | Multiple VPCs across both regions |
| **Segment Isolation** | `production` and `shared` segments are isolated |
| **Segment Sharing** | From `shared` to `production` and `development` |

---

![Simple Architecture](../../images/patterns_simple_architecture.png)

### Segment Configuration

| Segment | Isolation | Intra-Segment Communication |
|---------|-----------|----------------------------|
| **production** | ✅ Isolated | ❌ Blocked (isolated) |
| **development** | ❌ Not Isolated | ✅ Allowed |
| **shared** | ✅ Isolated | ❌ Blocked (isolated) |

**Segment Sharing**:

- The `shared` segment shares routes with both `production` and `development`.
- This allows workloads in `production` and `development` to access `shared` services.
- Shared services cannot communicate with each other (isolated).

### Attachment policy logic

The network policy includes two attachment policy rules that determine segment association:

#### Rule 100

```
IF attachment_type == "vpc" AND tag "domain" exists
THEN associate to segment matching the "domain" tag value
```

**Example**:

- VPC tagged with `domain=production` → Associates to `production` segment
- VPC tagged with `domain=development` → Associates to `development` segment

#### Rule 200

```
IF tag "sharedservice" == "true"
THEN associate to "shared" segment
```

**Example**:

- VPC tagged with `sharedservice=true` → Associates to `shared` segment

### Traffic Flow

| Source | Destination | Result | Reason |
|--------|-------------|--------|--------|
| Production VPC A | Production VPC B | ❌ Blocked | *production* segment is isolated |
| Development VPC A | Development VPC B | ✅ Allowed | *development* segment allows intra-segment traffic |
| Production VPC | Shared Services VPC | ✅ Allowed | Segment sharing enabled |
| Development VPC | Shared Services VPC | ✅ Allowed | Segment sharing enabled |
| Shared Service A | Shared Service B | ❌ Blocked | *shared* segment is isolated |
| Production VPC | Development VPC | ❌ Blocked | No segment sharing between *production* and *development* |

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
      "name": "development",
      "require-attachment-acceptance": false
    },
    {
      "name": "production",
      "require-attachment-acceptance": false,
      "isolate-attachments": true
    },
    {
      "name": "shared",
      "require-attachment-acceptance": false,
      "isolate-attachments": true
    }
  ],
  "segment-actions": [
    {
      "action": "share",
      "mode": "attachment-route",
      "segment": "shared",
      "share-with": [
        "development",
        "production"
      ]
    }
  ],
  "attachment-policies": [
    {
      "rule-number": 100,
      "condition-logic": "and",
      "conditions": [
        {
          "type": "tag-exists",
          "key": "domain"
        },
        {
          "type": "attachment-type",
          "operator": "equals",
          "value": "vpc"
        }
      ],
      "action": {
        "association-method": "tag",
        "tag-value-of-key": "domain"
      }
    },
    {
      "rule-number": 200,
      "condition-logic": "or",
      "conditions": [
        {
          "type": "tag-value",
          "operator": "equals",
          "key": "sharedservice",
          "value": "true"
        }
      ],
      "action": {
        "association-method": "constant",
        "segment": "shared"
      }
    }
  ]
}
```

## Implementation

| IaC Tool | Location | Documentation |
|----------|----------|---------------|
| **CloudFormation** | [`./cloudformation/`](./cloudformation/) | [CloudFormation README](./cloudformation/README.md) |
| **Terraform** | [`./terraform/`](./terraform/) | [Terraform README](./terraform/README.md) |

## Testing connectivity

After deployment, test connectivity between VPCs:

### 1. Verify segment associations

Check that VPCs are associated with the correct segments in the AWS Network Manager console.

### 2. Test intra-segment communication

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

### 3. Test access to Shared Services

**From Production to Shared Instances** (should work):

```bash
# From Production VPC, ping Shared Services VPC
ping <shared-vpc-instance-ip>
```

**From Development to Shared Instances** (should work):

```bash
# From Development VPC, ping Shared Services VPC
ping <shared-vpc-instance-ip>
```

### 4. Test cross-segment isolation

**Production to Development Instances** (should fail):

```bash
# From Production VPC, ping Development VPC
ping <dev-vpc-instance-ip>
# Expected: Timeout (no segment sharing)
```

## Troubleshooting

### VPCs not associating to segments

**Check**:

1. VPC has the correct `domain` tag
2. Cloud WAN attachment is in "Available" state
3. Policy is in "LIVE" state (not "PENDING")

### Cannot communicate between VPCs

**Check**:

1. VPC route tables have routes to Cloud WAN
2. Security groups allow required traffic
3. Network ACLs are not blocking traffic
4. Verify segment isolation settings match expectations

### Policy update fails

**Check**:

- Invalid JSON syntax
- Unsupported policy version
- Conflicting attachment policy rules
- Invalid segment references

## Next Steps

After mastering this simple architecture, explore:

1. **[Multi-Account Pattern](../2-multi_account/)** - Deploy across multiple AWS accounts
2. **[Traffic Inspection](../3-traffic_inspection/)** - Add centralized inspection
3. **[Routing Policies](../4-routing_policies/)** - Implement advanced routing controls
