# Infra pattern 5 — Multi-account (AWS CloudFormation)

A global network, a core network, and an AWS RAM share of that core network with one or more spoke accounts.

See [the pattern README](../README.md) for what this builds, what its baseline policy demonstrates, the cross-account limitations that matter, and how to verify it. See [`infra/README.md`](../../README.md) for cost, the tagging contract, and how to bring your own policy.

## Prerequisites

- An AWS account with permissions for CloudFormation, Network Manager, AWS RAM, and IAM. No EC2 permissions are needed — this pattern creates no workloads.
- The AWS CLI, configured with credentials.
- `make`, which drives the stack ordering.
- Python 3, if you intend to regenerate the policy template. The scripts in [`tools/`](../../../tools/) are standard-library only.

## Templates

| Template | Deploys | Region |
|----------|---------|--------|
| `core_network.yaml` | Global network, core network, and the policy | `us-east-1` |
| `ram_share.yaml` | The AWS RAM resource share of the core network | `us-east-1` |

`core_network.yaml` is **generated**. The policy comes from [`../baseline.json`](../baseline.json), the single source of truth shared with the Terraform implementation, because CloudFormation cannot take a document this size as a stack parameter — parameters cap at 4096 characters. Edit `baseline.json` and regenerate:

```bash
python3 tools/sync_cfn_policy.py infra/5-multi_account
```

CI fails if a generated template drifts from `baseline.json`.

## Deploy

```bash
cd infra/5-multi_account/cloudformation
```

Both stacks. `SPOKE_PRINCIPALS` is required:

```bash
make deploy SPOKE_PRINCIPALS="111122223333"
```

Several principals, or a spoke account outside your AWS Organization:

```bash
make deploy SPOKE_PRINCIPALS="111122223333,222233334444"
make deploy SPOKE_PRINCIPALS="111122223333" ALLOW_EXTERNAL=true
```

Show the core network ID and ARN a spoke account needs:

```bash
make outputs
```

## Deploying your own policy

CloudFormation needs the policy **inline** in the template — `PolicyDocument` takes JSON with no file or S3 option, and a stack parameter caps at 4,096 bytes, which a real policy exceeds. So instead of pointing at a different file, you deploy a different template.

`core_network.yaml` is generated and must not be edited by hand. Copy it instead:

```bash
cd infra/5-multi_account/cloudformation
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

`make undeploy` removes the RAM share first, then the core network. A core network with attachments from another account **cannot** be deleted, and the error does not name the cause, so the spoke accounts must remove their attachments before this succeeds.

To do it by hand:

```bash
make undeploy-share
make undeploy-cloudwan
```
