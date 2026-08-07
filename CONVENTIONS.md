# Repository Conventions

This document is the contract that **every published pattern** in this repository follows. New patterns and changes to existing patterns must conform to it. It is the authoritative, concise reference for naming, layout, dependency versions, license headers, network-policy authoring, and CloudFormation/Terraform parity.

> If you are adding or modifying a pattern, read this file first. CI and the local pre-commit hooks enforce much of it automatically.

---

## 1. Naming scheme

Two related forms are used, depending on whether the string is an AWS **resource name** or a human-facing **`Name` tag / description**.

**Resource names** are hyphenated, lowercase, with the `identifier` suffix last:

```
"<role>-<thing>-${var.identifier}"
```

| Resource | Name |
|----------|------|
| Network Firewall policy | `firewall-policy-${var.identifier}` |
| Stateless rule group | `drop-remote-${var.identifier}` |
| Stateful rule group | `allow-domains-${var.identifier}` |
| Transit Gateway | `tgw-${data.aws_region.current.region}-${var.identifier}` |

**Security groups** use the pattern:

```
"<vpc>-<purpose>-security-group-${var.identifier}"
```

e.g. `prod-eu-west-1-instance-security-group-${var.identifier}`.

**`Name` tags and descriptions** on Cloud WAN control-plane constructs may use a readable title-case form with a dash separator, which is what shows up in the Network Manager console:

```
"Global Network - ${var.identifier}"
"Core Network - ${var.identifier}"
"Transit Gateway Policy Table - ${data.aws_region.current.region}"
```

Rules that apply to both forms:

- **Hyphens, not underscores**, in resource names.
- **The `identifier` suffix comes last.**
- Use **full, readable words**. Do not introduce cryptic prefixes (`cnw-`, `gn-`) or suffix-first outliers (`${var.identifier}-tgw`).

---

## 2. Directory layout

### Layout

```
infra/<pattern>/                 # a pattern = which ATTACHMENT TYPES exist
├── terraform/                   # main.tf, variables.tf, outputs.tf, providers.tf,
│                                #   .header.md, README.md (generated)
├── cloudformation/              # templates, Makefile, README.md
│                                #   core_network.yaml is GENERATED - see section 6
├── baseline.json                # the pattern's working policy (single source of truth)
└── README.md                    # what it deploys, tags applied, how to test

infra/tf_modules/                # shared Terraform modules: compute, firewall_policy,
                                 #   transit_gateway

policy/                          # flat, one document per policy-document area
├── README.md                    # index, snippet vs example, testability matrix
├── policy_generator.md          # the authoring workflow
├── 1..6-*.md                    # the capability documents
└── examples/*.json              # complete, validated, deployable policies

tools/                           # validate_policy.py, sync_cfn_policy.py
images/                          # architecture diagrams + editable sources
```

Rules:

- An `infra/` pattern is defined **only** by which attachment types it creates. It must not encode a use case. If two candidate patterns would differ only in policy, they are one pattern and two policies.
- `baseline.json` is a **working** policy, not a placeholder: deploying a pattern unmodified must produce a network that forwards traffic.
- Every pattern applies the same [attachment tagging contract](infra/README.md#attachment-tags). Changing it is a local edit by the user, not a per-pattern variation.
- Shared Terraform modules live **only** in `infra/tf_modules/`. The name is deliberately Terraform-specific; CloudFormation templates are self-contained.
- Every pattern deploys exactly **two Regions** (`us-east-1`, `eu-west-1`). See [`infra/README.md`](infra/README.md#two-regions) for why, and what it costs. A pattern may declare a provider for a non-edge Region — `4-hybrid` needs `us-west-2` for managed prefix lists — keyed `home` in `aws_regions` so tooling excludes it from edge-location checks.
- The `terraform/README.md` is **generated** from `.header.md` plus the module's inputs and outputs. Edit `.header.md`, then regenerate — never edit the README by hand. Config: `.config/.terraform-docs.yaml`.
- `policy/` is flat. One markdown file per area of the policy document; the only subdirectory is `examples/`.

### Documentation tiers

`infra/` documentation is three tiers, and **each fact lives in exactly one of them**. The test for where something belongs is its scope: if it is true of every pattern it goes in tier 1, if it is true of one pattern it goes in tier 2, and if it is true of one pattern *and* one tool it goes in tier 3.

| Tier | File | Owns |
|---|---|---|
| 1 | [`infra/README.md`](infra/README.md) | Which AWS resources Cloud WAN is, the pattern catalog and how to choose, prerequisites, the conventions every pattern follows (Regions, attachment tags, the two IaC tools), and the bring-your-own-policy workflow |
| 2 | `infra/<pattern>/README.md` | What that pattern builds, its diagram, the tags it applies, what its baseline policy demonstrates and the resulting reachability, what it can and cannot exercise, how to verify it, and its **cost** |
| 3 | `infra/<pattern>/terraform/.header.md` and `infra/<pattern>/cloudformation/README.md` | Mechanics only: prerequisites specific to the tool, deploy, deploying your own policy, cleanup |

Rules:

- **Tier 3 explains no concepts.** If a paragraph would read identically in the other tool's README, it belongs in tier 1 or 2. Prerequisites and the reason to swap a policy are tier 1, cost is tier 2; a tier 3 file links up rather than restating them.
- **Both tier 3 files use the same section order**: title, one-line summary, pointer up to tiers 2 and 1, Prerequisites, Deploy, Deploying your own policy, Cleanup. CloudFormation adds a `Templates` table before Deploy because the stack split is genuinely part of the tool's structure. Terraform adds `Next steps` before the generated reference. A reader switching tools should find the same headings in the same order.
- **Do not hand-write a Terraform version** in `.header.md`. terraform-docs generates the *Requirements* table from the code, and that is the authoritative source.
- **Do not hard-wrap human-facing markdown.** One paragraph is one line. Wrapped prose is painful to edit and produces unreadable diffs for a one-word change.
- Every pattern README ends with a **`## Cost`** section: a table of what is created, how many, and how each is charged, then a line naming what dominates. Cost is per-pattern because the resources are — `2-inspection` is an order of magnitude more expensive than `5-multi_account`.
- `5-multi_account` is the documented exception to tier 2: it has no workloads, so no reachability table. Its README carries the multi-account capabilities and limitations instead.

## 3. Version pins

A single pinned set is applied to every pattern. **Modules are exact-pinned with `=`; providers use a single floor `>=`.**

| Dependency | Pin | Form |
|------------|-----|------|
| `hashicorp/aws` (provider) | `6.34.0` | `version = ">= 6.34.0"` (floor) |
| `hashicorp/awscc` (provider) | `1.67.0` | `version = ">= 1.67.0"` (floor) |
| `aws-ia/vpc/aws` (module) | `4.7.3` | `version = "= 4.7.3"` (exact) |
| `aws-ia/cloudwan/aws` (module) | `3.4.0` | `version = "= 3.4.0"` (exact) |
| `aws-ia/networkfirewall/aws` (module) | `1.0.2` | `version = "= 1.0.2"` (exact) |
| Terraform core | `1.3.0` | `required_version = ">= 1.3.0"` (floor) |

Conventions:

- **Modules → exact pin** with an explicit `=` operator (e.g. `version = "= 4.7.3"`), making the exact-pin intent unambiguous. A bare `version = "3.4.0"` is also an exact pin in Terraform, but the explicit operator states the intent, so use it.
- **Providers → single floor** (`>= x.y.z`). Raise all patterns to the agreed floor; never lower it.
- The rule for choosing a value is "highest currently-used stable value, applied uniformly."
- `required_version = ">= 1.3.0"` is uniform across every `providers.tf`, including child modules.
- Provider **lock files are not committed** (`.terraform.lock.hcl` is gitignored). Because providers are floor-pinned, each `terraform init` resolves the newest matching provider, which is what CI validates against.

---

## 4. License header

Every IaC source file carries the `MIT-0` copyright header at the very top.

**Terraform (`*.tf`)** — block comment:

```hcl
/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */
```

**CloudFormation / YAML (`*.yaml`)** — hash comment lines before `AWSTemplateFormatVersion`:

```yaml
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
```

For any other comment-supporting source file (Makefile, shell, Python), use the equivalent comment syntax with the same two lines.

**Markdown does not carry the header.** `LICENSE` at the repository root covers the repository, and an SPDX header exists for source files that may be copied out of it in isolation — which is not what documentation is for. Every `*.md` in this repository starts with its `#` heading.

---

## 5. Cloud WAN facts to state consistently

These are properties of the service, not of this repository. State them the same way everywhere.

| Fact | Value |
|------|-------|
| Network policy version used by every pattern | `2025.11` |
| Cloud WAN home Region | `us-west-2` |
| Control-plane console | AWS Network Manager |
| Managed prefix lists referenced by routing policies | MUST be created in `us-west-2`, regardless of where edge locations are |
| Core Network Edge (CNE) throughput | up to 100 Gbps per CNE |

The `awscc` provider alias that creates the global network and core network is pointed at a single Region per pattern (the patterns use `us-east-1`); this is the API endpoint used to manage the core network, not a constraint on edge locations.

When a pattern's docs claim a routing behaviour, the **network policy in the docs must match the policy the IaC actually deploys**. Where prose and policy disagree, the deployed policy is authoritative and the prose is the bug.

---

## 6. Network-policy authoring

### v2: one document, generated CloudFormation

In the v2 layout each `infra/` pattern's `baseline.json` is the **single source of truth** for its network policy.

- **Terraform** reads it with `file(var.policy_document)`. The `aws_networkmanager_core_network_policy_document` data source is deliberately **not** used, so the policy is not authored a second time in HCL.
- **CloudFormation** cannot take a document this size as a stack parameter (parameters cap at 4096 characters), so `cloudformation/core_network.yaml` is **generated** from `baseline.json`:

  ```bash
  python3 tools/sync_cfn_policy.py infra/<pattern>
  ```

  Never hand-edit that file. CI fails if it drifts.

Every policy — baselines, `policy/examples/*.json`, and the inline snippets in `policy/*.md` — must pass `tools/validate_policy.py`. A baseline must also pass the contract check against its own pattern:

```bash
python3 tools/validate_policy.py infra/<pattern>/baseline.json --infra infra/<pattern>
```

### Snippets versus examples in `policy/`

- A **snippet** is a fragment (one array element, or one array), illustrative and not deployable alone. It lives inline in the markdown. Snippets are the default.
- An **example** is a complete, valid, deployable policy document in `policy/examples/`.

An example is admissible only if **all four** hold:

1. It cannot be understood from the snippets alone — the value is in the *interaction* between two or more capabilities.
2. It is deployable end to end against a named infra pattern, so it can be verified rather than merely read.
3. It produces a routing outcome that is non-obvious, or easy to get wrong when composing the snippets by hand.
4. It does **not** differ from an existing example only by parameter values (CIDRs, Region names, segment names, community values). Parameterisation is not novelty.

Every example must appear in the table in [`policy/README.md`](policy/README.md) with a one-line justification. If you cannot write that sentence, what you have is a snippet. **This is checked in review** — it is the mechanism that stops the example directory growing into the v1 pattern sprawl.

## 7. CloudFormation / Terraform parity policy

Every `infra/` pattern ships **both** a CloudFormation and a Terraform implementation of its core network and its workloads.

One documented exception: in [`4-hybrid`](infra/4-hybrid/) the **hybrid attachments** (Site-to-Site VPN, Connect, Direct Connect gateway) and the **managed prefix lists** are Terraform-only. Each hybrid sub-type is enabled selectively because their prerequisites differ — a BGP peer, an SD-WAN appliance, a real Direct Connect circuit — which maps cleanly onto Terraform's optional-object variables and awkwardly onto CloudFormation `Conditions`. The policy side is identical either way, so a hybrid attachment created by hand still associates correctly. The exception is stated in the pattern's CloudFormation README and in [`blueprint.yaml`](blueprint.yaml).

[`blueprint.yaml`](blueprint.yaml) is the machine-readable catalog and the **source of truth for what exists**. Never claim an implementation that is not on disk. When you add or remove one, update `blueprint.yaml` in the same change.

## 8. Security-scan baseline & suppression mechanism

CI runs [Checkov](https://www.checkov.io/) over the repository using the committed [`.checkov.yaml`](.checkov.yaml) baseline at the repo root. These blueprints are intentionally minimal teaching examples, so some findings map to deliberate demo simplifications (open egress, EC2 instances without instance profiles, short log retention) or to confirmed false positives (SSH ingress that is actually scoped to the EC2 Instance Connect security group).

There are **two ways to suppress a finding**, both supported:

1. **Repo-wide**: add the check ID to the `skip-check` list in `.checkov.yaml`, with a trailing one-line justification comment. Use this for simplifications/false positives that recur across patterns.
2. **Inline, per-resource**: add a skip comment on the offending resource so the rest of the repo still gets the check:
   - Terraform: `#checkov:skip=CKV_AWS_123:reason it is safe here`
   - CloudFormation: `# checkov:skip=CKV_AWS_123:reason it is safe here`

   Always include the `:reason`.

Rules of thumb:

- Suppress **only** deliberate demo simplifications or confirmed false positives; never genuinely security-relevant defaults. Encryption at rest, IMDSv2, and encrypted EBS root volumes must stay enforced.
- Every suppression carries a justification (comment or `:reason`).
- The baseline is **expected to evolve**: entries are added/removed as findings are triaged and patterns change. The `.checkov.yaml` header comment is the authoritative reference for the current set and the rationale behind each skip.

---

## 9. CI / pre-commit lockstep

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) and [`.pre-commit-config.yaml`](.pre-commit-config.yaml) run the **same** checks with the **same** pinned tool versions, so a contributor can reproduce a CI failure locally. A change to one MUST be mirrored in the other.

| Check | CI job | pre-commit hook | Pinned version | Blocking in CI |
|-------|--------|-----------------|----------------|----------------|
| Terraform formatting | `fmt` | `terraform_fmt` | Terraform `1.9.8` | yes |
| Terraform validate | `terraform-checks` | `terraform_validate` | Terraform `1.9.8` | yes |
| Terraform lint | `tflint` | `terraform_tflint` | tflint `v0.61.0`, AWS ruleset `0.42.0` | yes |
| CloudFormation lint | `cfn-lint` | `cfn-lint` | cfn-lint `1.46.0` | yes |
| Generated README drift | `terraform-docs` | `terraform_docs` | terraform-docs `v0.21.0` | yes |
| Policy validation (baselines + examples) | `policy` | `validate-policies` | repo script, no dependencies | yes |
| Policy snippet validation | `policy` | `validate-policy-snippets` | repo script, no dependencies | yes |
| Generated CFN policy drift | `policy` | `sync-cfn-policy` | repo script, no dependencies | yes |
| Markdown links | `markdown-links` | `lychee` (local hook) | lychee action `v2` | yes |
| IaC security scan | `checkov` | `checkov` | checkov `3.2.500` | **no** (`soft_fail: true`) |

Notes:

- Everything is **static**. No job configures AWS credentials, initializes a state backend, or creates a resource. `terraform validate` runs behind `terraform init -backend=false`.
- The `discover` job **enumerates pattern directories automatically** by globbing `infra/` for `*.tf` and `cloudformation/*.yaml`. Adding or restructuring patterns does not require editing the workflow — which is what made the v2 migration possible without rewriting CI.
- The `policy` job runs the two repository scripts in `tools/`. They use only the Python standard library, so there is no install step and no dependency to pin.
- `checkov` is the one non-blocking gate. Flip `soft_fail: true` to `false` once the baseline is fully triaged.
- `ci-passed` is an aggregator job that depends on every other job. Configure **only** that check in branch protection. If you add a new top-level job, add it to `ci-passed`'s `needs` list.
- Version pins here are deliberate. The sibling [Amazon VPC Lattice Blueprints](https://github.com/aws-samples/amazon-vpc-lattice-blueprints) repository runs the same pipeline shape; when raising a tool version, prefer raising it in both.

Run the checks locally before opening a pull request:

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

The Terraform, tflint, terraform-docs, and lychee hooks shell out to locally installed binaries; cfn-lint and checkov are installed automatically by pre-commit into isolated hook environments.
