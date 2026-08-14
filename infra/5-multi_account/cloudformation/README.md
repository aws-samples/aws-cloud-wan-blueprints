# Infrastructure-as-Code Patterns — AWS Cloud WAN shared across accounts (AWS CloudFormation)

In this pattern, we want to show how a core network is shared with other AWS accounts using AWS Resource Access Manager.

![Multi-account architecture](../../../images/5-multi_account.png)

See [the pattern README](../README.md) for what this builds, why two Regions are involved, what its baseline policy configures, and how to verify it.

## Prerequisites

- An AWS account with permissions for CloudFormation, Network Manager, AWS RAM, and IAM. No EC2 permissions are needed — this pattern creates no workloads.
- **A second AWS account to share with** — the spoke account — or an organizational unit or organization containing one. The deployment succeeds without it, because RAM will happily share with a principal you do not control — but nothing can be verified until the spoke account accepts the share and creates an attachment.
- The AWS CLI, configured with credentials.
- `make`, which drives the stack ordering.

## Templates

| Template | Deploys | Region |
|----------|---------|--------|
| `core_network.yaml` | Global network, core network, and the policy | `us-west-2` |
| `ram_share.yaml` | The AWS RAM resource share of the core network | `us-east-1` |

## Deploy

```bash
cd infra/5-multi_account/cloudformation
make deploy PRINCIPAL=111122223333
```

That deploys the pattern with its working baseline policy: the core network first, then the share. To take it a stack at a time, `make deploy-cloudwan` then `make deploy-share PRINCIPAL=...`.

`PRINCIPAL` is required and `PRINCIPAL_TYPE` defaults to `account`. To share with an organizational unit or a whole organization, set both:

```bash
make deploy PRINCIPAL_TYPE=organizational_unit PRINCIPAL=arn:aws:organizations::111122223333:ou/o-abc123def4/ou-ab12-cdef3456
make deploy PRINCIPAL_TYPE=organization       PRINCIPAL=arn:aws:organizations::111122223333:organization/o-abc123def4
```

Print the core network ID and ARN a spoke account needs, plus the resource share ARN:

```bash
make outputs
```

> **Sharing with an organizational unit or an organization needs one-off setup.** Run `aws ram enable-sharing-with-aws-organization` once, from the management account. Until then RAM accepts individual account IDs only. Those shares are also auto-accepted, whereas sharing with an account ID sends an invitation the spoke account has to accept.

> **Using a policy of your own?** CloudFormation needs the policy **inline** in the template — `PolicyDocument` takes JSON with no file or S3 option, and a stack parameter caps at 4,096 bytes — so instead of pointing at a different file you deploy a different template. `core_network.yaml` has to keep matching [`../baseline.json`](../baseline.json), which CI compares, so copy it rather than editing it.

## Cleanup

```bash
cd infra/5-multi_account/cloudformation
make undeploy
```

That removes the share first, then the core network. A core network with attachments from a spoke account cannot be deleted, and the error does not name the cause, so every spoke account has to remove its attachments before this succeeds. To do it a stack at a time, `make undeploy-share` then `make undeploy-cloudwan`.
