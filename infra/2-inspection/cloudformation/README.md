# Infra pattern 2 — Inspection (AWS CloudFormation)

Spoke VPCs plus an inspection VPC with AWS Network Firewall per Region, attached to a Cloud WAN network function group.

See [the pattern README](../README.md) for what this builds, the attachment tags it applies, what its baseline policy demonstrates, and how to verify it. See [`infra/README.md`](../../README.md) for cost, the tagging contract, and how to bring your own policy.

## Prerequisites

- An AWS account with permissions for CloudFormation, Network Manager, Network Firewall, EC2 (VPCs, subnets, instances, endpoints, NAT gateways), and IAM.
- The AWS CLI, configured with credentials.
- `make`, which drives the stack ordering.
- Python 3, if you intend to regenerate the policy template. The scripts in [`tools/`](../../../tools/) are standard-library only.

## Templates

| Template | Deploys | Region |
|----------|---------|--------|
| `base_policy.yaml` | Global network and core network **without** the service-insertion actions | `us-east-1` |
| `workloads.yaml` | Spoke VPCs, inspection VPC, Network Firewall, instances | Once per Region |
| `core_network.yaml` | The same core network, updated with the **full** policy | `us-east-1` |

`base_policy.yaml` and `core_network.yaml` are **generated**. The policy comes from [`../baseline.json`](../baseline.json), the single source of truth shared with the Terraform implementation, because CloudFormation cannot take a document this size as a stack parameter — parameters cap at 4096 characters. Edit `baseline.json` and regenerate:

```bash
python3 tools/sync_cfn_policy.py infra/2-inspection
```

CI fails if a generated template drifts from `baseline.json`.

## Why the deploy is split

A `send-to` or `send-via` action cannot reference a network function group that has no attachments yet. So the core network is created without service insertion, the workloads attach into the network function group, and the policy is then updated to route through it.

Terraform does not need this — its dependency graph orders the same work inside one `apply`.

Both templates come from the one `baseline.json`. The generator strips **only** the service-insertion `segment-actions` to produce the base policy, so the network function group and every attachment policy are present in both — which is what lets phase 2 attach into the group.

## Deploy

```bash
cd infra/2-inspection/cloudformation
```

All three phases in order:

```bash
make deploy
```

Or phase by phase:

```bash
make deploy-base-policy   # core network, no service insertion
make deploy-workloads     # spoke and inspection VPCs, both Regions
make update-cloudwan      # core network updated with the full policy
```

> **Cost:** an EC2 instance is created in **every** Availability Zone configured for each VPC, so the count grows with the AZ count. For production use at least two AZs. See [Cost](../README.md#cost) for the full breakdown.

## Deploying your own policy

CloudFormation needs the policy **inline** in the template — `PolicyDocument` takes JSON with no file or S3 option, and a stack parameter caps at 4,096 bytes, which a real policy exceeds. So instead of pointing at a different file, you deploy a different template.

`base_policy.yaml` and `core_network.yaml` are generated and must not be edited by hand. Copy them instead:

```bash
cd infra/2-inspection/cloudformation
cp core_network.yaml my_core_network.yaml

# Replace the PolicyDocument: block in my_core_network.yaml with your policy as YAML,
# then deploy your copy:
make update-cloudwan CORE_TEMPLATE=my_core_network.yaml
```

[`../../../policy/policy_generator.md`](../../../policy/policy_generator.md) hands you that YAML block directly — tell it you are deploying with CloudFormation and it returns the policy in both JSON and YAML, with the type-conversion traps already handled.

Updating the core network stack replaces the policy in place. You do **not** need to tear down the workloads: segments and routing can be changed on a live core network.

If you would rather not touch templates at all, use [`../terraform/`](../terraform/) — it takes any policy file as a variable.

## Cleanup

```bash
make undeploy
```

`make undeploy` removes the workload stacks first so the core network has no attachments left, then the core network. Deleting a core network that still has attachments fails, and the error does not name the cause.

To do it by hand:

```bash
make undeploy-workloads
make undeploy-cloudwan
```
