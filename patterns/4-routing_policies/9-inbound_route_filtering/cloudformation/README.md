# AWS Cloud WAN Inbound Route Filtering (AWS CloudFormation)

## Prerequisites

- **AWS Account**: With appropriate IAM permissions
- **AWS CLI**: Installed and configured
- **Hybrid Connectivity**: Direct Connect Gateway with BGP sessions established
- **Make**: Installed

## Deployment

```bash
cd patterns/4-routing_policies/9-inbound_route_filtering/cloudformation

# Deploy Core Network + DX Gateway + Prefix List
make deploy

# After deployment, associate the prefix list with the Core Network:
make associate-prefix-list
```

## Cleanup

```bash
make undeploy
```
