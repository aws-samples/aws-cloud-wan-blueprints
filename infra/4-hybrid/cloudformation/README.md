# Infra pattern 4 — Hybrid (AWS CloudFormation)

Spoke VPCs plus optional Site-to-Site VPN, Connect, and Direct Connect gateway attachments, and managed prefix lists for route summarization.

See [the pattern README](../README.md) for what this builds, the attachment tags it applies, what its baseline policy demonstrates, and how to verify it. See [`infra/README.md`](../../README.md) for cost, the tagging contract, and how to bring your own policy.

## Prerequisites

- An AWS account with permissions for CloudFormation, Network Manager, EC2 (VPCs, subnets, instances, endpoints, VPN, managed prefix lists), Direct Connect, and IAM.
- The AWS CLI, configured with credentials.
- `make`, which drives the stack ordering.
- Python 3, if you intend to regenerate the policy template. The scripts in [`tools/`](../../../tools/) are standard-library only.

## Templates

| Template | Deploys | Region |
|----------|---------|--------|
| `core_network.yaml` | Global network, core network, and the policy — including attachment-type association for hybrid attachments | `us-east-1` |
| `workloads.yaml` | Spoke VPCs, EC2 instances, EC2 Instance Connect endpoint | Once per Region |

`core_network.yaml` is **generated**. The policy comes from [`../baseline.json`](../baseline.json), the single source of truth shared with the Terraform implementation, because CloudFormation cannot take a document this size as a stack parameter — parameters cap at 4096 characters. Edit `baseline.json` and regenerate:

```bash
python3 tools/sync_cfn_policy.py infra/4-hybrid
```

CI fails if a generated template drifts from `baseline.json`.

## Why the deploy is split

**The hybrid attachments and the managed prefix lists are not deployed here — they are Terraform-only.**

The policy side is unaffected: attachment-type association for `site-to-site-vpn`, `connect`, and `direct-connect-gateway` is in the generated `core_network.yaml` exactly as it is in the baseline. So a hybrid attachment you create by hand, or from your own template, against a core network deployed this way still lands in the `hybrid` segment automatically. No policy change is needed.

Use [`../terraform/`](../terraform/) to have the hybrid attachments and prefix lists deployed for you.

## Deploy

```bash
cd infra/4-hybrid/cloudformation
```

Core network and spoke VPCs in both Regions:

```bash
make deploy
```

Or step by step:

```bash
make deploy-cloudwan
make deploy-workloads
```

> **Cost:** an EC2 instance is created in **every** Availability Zone configured for each VPC, so the count grows with the AZ count. For production use at least two AZs. See [Cost](../README.md#cost) for the full breakdown.

## Deploying your own policy

CloudFormation needs the policy **inline** in the template — `PolicyDocument` takes JSON with no file or S3 option, and a stack parameter caps at 4,096 bytes, which a real policy exceeds. So instead of pointing at a different file, you deploy a different template.

`core_network.yaml` is generated and must not be edited by hand. Copy it instead:

```bash
cd infra/4-hybrid/cloudformation
cp core_network.yaml my_core_network.yaml

# Replace the PolicyDocument: block in my_core_network.yaml with your policy as YAML,
# then deploy your copy:
make deploy-cloudwan CORE_TEMPLATE=my_core_network.yaml
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
