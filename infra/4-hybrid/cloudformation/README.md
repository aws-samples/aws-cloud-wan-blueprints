# Infrastructure-as-Code Patterns — AWS Cloud WAN with hybrid connectivity (AWS CloudFormation)

In this pattern, we want to show how AWS Cloud WAN integrates with AWS Site-to-Site VPN and AWS Direct Connect to achieve hybrid connectivity.

![Hybrid architecture](../../../images/4-hybrid.png)

See [the pattern README](../README.md) for what this builds, how its attachments associate, what its baseline policy configures, and how to verify it.

## Prerequisites

- An AWS account with permissions for CloudFormation, Network Manager, EC2 (VPCs, subnets, instances, endpoints, customer gateways, VPN connections), Direct Connect, and IAM.
- The AWS CLI, configured with credentials.
- `make`, which drives the stack ordering.

## Templates

| Template | Deploys | Region |
|----------|---------|--------|
| `core_network.yaml` | Global network, core network, and the policy | `us-east-1` |
| `workloads.yaml` | Spoke VPC, EC2 instances, EC2 Instance Connect endpoint | Once per Region |
| `hybrid.yaml` | Site-to-Site VPN and Direct Connect gateway attachments | `us-east-1` |

## Deploy

```bash
cd infra/4-hybrid/cloudformation
make deploy
```

That deploys the pattern with its working baseline policy: the core network first, then the workloads in both Regions. To take it a stack at a time, `make deploy-cloudwan` then `make deploy-workloads`.

The hybrid attachments are a separate stack and are off by default, because each needs a value only you can supply. Neither ASN may overlap the core network's `asn-ranges`, which the baseline sets to `64520-64525`.

The Site-to-Site VPN is created in `us-east-1`. Both values describe your on-premises device:

```bash
make deploy-hybrid CUSTOMER_GATEWAY_IP=203.0.113.10 CUSTOMER_GATEWAY_ASN=65010
```

The Direct Connect gateway needs only its Amazon-side ASN:

```bash
make deploy-hybrid DXGW_ASN=64534
```

> **This pattern builds the AWS side only.** The VPN tunnels stay down until a real on-premises peer answers, and the Direct Connect gateway carries no traffic until you associate a Transit VIF with it — creating the Transit VIFs and their association is out of scope here. What you can verify is the integration itself: that each hybrid attachment reaches the `hybrid` segment. Testing the path end to end is yours to do.

> **Using a policy of your own?** CloudFormation needs the policy **inline** in the template — `PolicyDocument` takes JSON with no file or S3 option, and a stack parameter caps at 4,096 bytes — so instead of pointing at a different file you deploy a different template. `core_network.yaml` has to keep matching [`../baseline.json`](../baseline.json), which CI compares, so copy it rather than editing it.

## Cleanup

```bash
cd infra/4-hybrid/cloudformation
make undeploy
```

That removes the hybrid stack and the workload stacks first, then the core network. The order matters: deleting a core network that still has attachments fails, and the error does not name the cause. To do it a stack at a time, `make undeploy-hybrid`, `make undeploy-workloads`, then `make undeploy-cloudwan`.
