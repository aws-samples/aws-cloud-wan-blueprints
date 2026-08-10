# Infrastructure-as-Code Patterns — AWS Cloud WAN prefix list association (AWS CloudFormation)

In this pattern, we want to show how a managed prefix list is associated with a core network so a routing policy can match on its alias, and how to deploy that without hitting the circular dependency between the two.

<!-- DIAGRAM PLACEHOLDER -->
> _Architecture diagram to be added._

See [the pattern README](../README.md) for what this builds, why two policy documents are needed, what each one configures, and how to verify it.

## Prerequisites

- An AWS account with permissions for CloudFormation, Network Manager, EC2 (managed prefix lists), and IAM. No VPC or EC2 instance permissions are needed — this pattern creates no workloads.
- The AWS CLI, configured with credentials.
- `make`, which drives the phase ordering.

## Templates

| Template | Deploys | Region |
|----------|---------|--------|
| `core_network.yaml` | Global network, core network, and the policy **without** the prefix list alias | `us-west-2` |
| `prefix_list.yaml` | The managed prefix list and its association with the core network | `us-west-2` |
| `core_network_prefix_list.yaml` | The same core network stack, with the policy that **does** reference the alias | `us-west-2` |

## Deploy

```bash
cd infra/6-prefix_list_association/cloudformation
make deploy
```

That runs the three phases in order. To take them one at a time:

```bash
make deploy-cloudwan      # phase 1 - core network, policy without the alias
make deploy-prefix-list   # phase 2 - prefix list + association
make deploy-policy        # phase 3 - same stack, policy with the alias
```

Phase 3 is a plain stack update: same stack name as phase 1, a different template, and the policy is replaced in place.

```bash
make outputs
```

> **Why two policy documents?** A routing policy matches a prefix list by **alias**, and the alias only exists once the prefix list is associated with the core network. The association needs a core network ID, so the core network must already exist — and AWS Cloud WAN rejects a policy naming an alias it cannot resolve. That's why `core_network.yaml` is applied first, and later on the final policy document is configured via `core_network_prefix_list.yaml` (once the prefix list is already created and associated).

> **Using a policy of your own?** CloudFormation needs the policy **inline** in the template — `PolicyDocument` takes JSON with no file or S3 option, and a stack parameter caps at 4,096 bytes — so instead of pointing at a different file you deploy a different template. `core_network.yaml` has to keep matching [`../baseline.json`](../baseline.json) and `core_network_prefix_list.yaml` has to keep matching [`../baseline_prefix_list.json`](../baseline_prefix_list.json), both of which CI compares, so copy them rather than editing them. If your policy references a different alias, pass `PREFIX_LIST_ALIAS` to `make deploy-prefix-list` as well.

## Cleanup

```bash
cd infra/6-prefix_list_association/cloudformation
make undeploy
```

That reverses the three phases, and the first step is to put the policy **without** the alias back:

```bash
make revert-policy         # policy stops referencing the alias
make undeploy-prefix-list  # association and prefix list can now be deleted
make undeploy-cloudwan
```

The revert is not optional. An association cannot be deleted while a live policy still matches on its alias — the same dependency as on the way up, in reverse.
