# AWS Cloud WAN Centralized Outbound Inspection (AWS CloudFormation)

![Centralized Outbound](../../../../images/centralizedOutbound.png)

## Prerequisites

- **AWS Account**: With appropriate IAM permissions
- **AWS CLI**: Installed and configured with credentials
- **Permissions required**:
  - CloudFormation
  - Network Manager
  - EC2: VPC, subnets, instances, endpoints, Network Firewall
  - IAM: Create roles and policies
- **Make**: Installed

## Deployment

```bash
# Clone the repository
git clone https://github.com/aws-samples/aws-cloud-wan-blueprints.git

# Navigate to the CloudFormation directory
cd patterns/3-traffic_inspection/1-centralized_outbound/cloudformation

# Deploy everything (Core Network + Workloads in all regions)
make deploy

# Or deploy step-by-step:
make deploy-base-policy  # Deploy base Core Network policy first
make deploy-workloads    # Then deploy workloads in all regions
make update-cloudwan     # Update Core Network with full policy (segment-actions)
```

> **Note**: EC2 instances will be deployed in all the Availability Zones configured for each VPC. Keep this in mind when testing this environment from a cost perspective - for production environments, we recommend the use of at least 2 AZs for high-availability.

## Cleanup

```bash
# Delete everything
make undeploy

# Or delete step-by-step:
make undeploy-workloads  # Delete workloads first
make undeploy-cloudwan   # Then delete Core Network
```

## Next Steps

After successfully deploying this pattern:

1. **Explore the architecture**: Review segment associations and NFG in Network Manager console
2. **Test connectivity**: Verify egress traffic is inspected (check Network Firewall logs)
3. **Try modifications**: Add VPCs, change firewall rules, update policies
4. **Advanced patterns**: Move to [East-West patterns](../../3-east_west_dualhop/) or [Routing policies](../../../4-routing_policies/) patterns
