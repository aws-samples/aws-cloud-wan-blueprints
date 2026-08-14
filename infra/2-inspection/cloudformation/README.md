# Infrastructure-as-Code Patterns — AWS Cloud WAN with traffic inspection (AWS CloudFormation)

In this pattern, we want to show how AWS Cloud WAN steers traffic through a firewall using service insertion - adding an Inspection VPC with AWS Network Firewall in each Region. Users can test egress (internet-bound) inspection, east-west inspection between segments, and how segment isolation behaves when only some traffic is inspected.

![Inspection architecture](../../../images/2-inspection.png)

See [the pattern README](../README.md) for what this builds, the attachment tags it applies, what its baseline policy configures, and how to verify it.

## Prerequisites

- An AWS account with permissions for CloudFormation, Network Manager, Network Firewall, EC2 (VPCs, subnets, instances, endpoints, NAT gateways), and IAM.
- The AWS CLI, configured with credentials.
- `make`, which drives the stack ordering.

## Templates

| Template | Deploys | Region |
|----------|---------|--------|
| `core_network.yaml` | Global network, core network, and the policy | `us-east-1` |
| `workloads.yaml` | Spoke VPCs, Inspection VPC, Network Firewall, instances | Once per Region |

## Deploy

```bash
cd infra/2-inspection/cloudformation
make deploy
```

That deploys the pattern with its working baseline policy: the core network first, then the workloads in both Regions. To take it a stack at a time, `make deploy-cloudwan` then `make deploy-workloads`.

> **Using a policy of your own?** CloudFormation needs the policy **inline** in the template — `PolicyDocument` takes JSON with no file or S3 option, and a stack parameter caps at 4,096 bytes — so instead of pointing at a different file you deploy a different template. `core_network.yaml` has to keep matching [`../baseline.json`](../baseline.json), which CI compares, so copy it rather than editing it.

## Cleanup

```bash
cd infra/2-inspection/cloudformation
make undeploy
```

That removes the workload stacks first, then the core network. The order matters: deleting a core network that still has attachments fails, and the error does not name the cause. To do it a stack at a time, `make undeploy-workloads` then `make undeploy-cloudwan`.
