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
│                                #   core_network*.yaml is GENERATED - see section 6
├── baseline.json                # the normal working policy
├── baseline_<stage>.json        # optional staged policy - see section 6
└── README.md                    # what it deploys, tags applied, how to test

infra/tf_modules/                # shared Terraform modules: compute, firewall_policy

policy/                          # flat, one document per policy-document area
├── README.md                    # index, composition guidance, validation workflow
└── 1..9-*.md                    # the capability documents

.github/scripts/                 # check_policies.py - CI pre-merge policy checks
images/                          # architecture diagrams + editable sources
```

Rules:

- An `infra/` pattern is defined **only** by which attachment types it creates. It must not encode a use case. If two candidate patterns would differ only in policy, they are one pattern and two policies.
- `baseline.json` is a **working** policy, not a placeholder: deploying a pattern unmodified must produce a network that forwards traffic. A pattern may add suffix-paired `baseline_<stage>.json` and `cloudformation/core_network_<stage>.yaml` documents only when a service dependency requires policies to be applied in stages; see [Network-policy authoring](#6-network-policy-authoring).
- A pattern binds attachments either by tag or by attachment type, and [`infra/README.md`](infra/README.md#how-attachments-are-associated) records which one each pattern uses. Tag keys are `domain` for segment association and `inspection` for the inspection network function group; do not invent a third. Changing what a pattern applies is a local edit by the user.
- Shared Terraform modules live **only** in `infra/tf_modules/`. The name is deliberately Terraform-specific; CloudFormation templates are self-contained.
- Every baseline declares exactly **two Core Network Edge locations**, `us-east-1` and `eu-west-1`, so the examples expose cross-Region behavior. The resources a pattern manages do not necessarily live in both edge Regions: [`infra/README.md`](infra/README.md#regions) records their actual locations and explains the exceptions for `5-multi_account` and `6-prefix_list_association`.
- The `terraform/README.md` is **generated** from `.header.md` plus the module's inputs and outputs. Edit `.header.md`, then regenerate — never edit the README by hand. Config: `.config/.terraform-docs.yaml`.
- `policy/` is flat: one markdown file per area of the policy document, no subdirectories.

### Catalog and agent-index synchronization

The repository exposes the same structure to human readers and AI agents. Keep those indexes synchronized in the same change:

- When a pattern is added, removed, or renamed, update the catalogs in [`README.md`](README.md), [`infra/README.md`](infra/README.md), and [Choosing infrastructure](SKILLS.md#5-choosing-infrastructure).
- When a policy capability page is added, removed, or renamed, update [`README.md`](README.md), [`policy/README.md`](policy/README.md), the [`SKILLS.md`](SKILLS.md#policy--the-capability-pages) capability table, the [assembly order](SKILLS.md#2-assembly-order), and any affected constraint-checklist entries.

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

**Markdown does not carry the header.** `LICENSE` at the repository root covers the repository, and an SPDX header exists for source files that may be copied out of it in isolation — which is not what documentation is for. Repository documentation outside `.github/ISSUE_TEMPLATE/` starts with its `#` heading; GitHub issue templates begin with the YAML front matter required by GitHub and then use Markdown headings.

---

## 5. Cloud WAN facts to state consistently

These are properties of the service, not of this repository. State them the same way everywhere.

| Fact | Value |
|------|-------|
| Network policy version used by every pattern | `2025.11` |
| Cloud WAN home Region | `us-west-2` |
| Control-plane console | AWS Network Manager |
| Managed prefix lists referenced by routing policies | MUST be created in `us-west-2`, regardless of where edge locations are |
| Throughput | A property of the **attachment**, not of the CNE. You scale a Region by adding or resizing attachments |
| Core Network Edge (CNE) cost | Charged **per hour** from the moment the policy declares it, attached or not |

**Never quote a number that lives in a quotas or a pricing page.** Limits and prices change, and a figure copied in here goes stale silently — the reader has no way to tell whether they are looking at a current value or one that was true when the page was written. State the **concept** and the **unit of measurement**, then link to the authoritative page:

- Throughput: say that it is per attachment, and per Availability Zone for VPC attachments, and link to [AWS Cloud WAN quotas](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html). Do not give Gbps figures.
- Cost: say what the unit is — a CNE is billed **per hour**, data processing **per GB** — and link to [AWS Cloud WAN pricing](https://aws.amazon.com/cloud-wan/pricing/). Do not give rates.

Numbers fixed by the service's own semantics rather than by a quota **are** worth stating, because a policy is invalid without them: the accepted `asn-ranges` bounds, the `/24` and `/64` minimums for inside CIDR blocks, the `/29` from `169.254.0.0/16` for Connect peer BGP addresses, and the `version` identifiers.

The `awscc` provider alias that creates the global network and core network is pointed at a single Region per pattern (the patterns use `us-east-1`); this is the API endpoint used to manage the core network, not a constraint on edge locations.

When a pattern's docs claim a routing behaviour, the **network policy in the docs must match the policy the IaC actually deploys**. Where prose and policy disagree, the deployed policy is authoritative and the prose is the bug.

---

## 6. Network-policy authoring

### v2: baseline documents and generated CloudFormation

In the normal v2 layout, an `infra/` pattern's `baseline.json` is the **single source of truth** for its network policy. When a service dependency requires more than one policy application, a pattern may add suffix-paired documents such as `baseline_prefix_list.json` and `cloudformation/core_network_prefix_list.yaml`. The unsuffixed pair remains the policy used to create the core network; each suffixed pair represents a later stage and must be documented in the pattern README.

- **Terraform** reads each policy document with `file(...)`. The `aws_networkmanager_core_network_policy_document` data source is deliberately **not** used, so a policy is not authored a second time in HCL.
- **CloudFormation** cannot take a document this size as a stack parameter (parameters cap at 4096 characters), so each `cloudformation/core_network*.yaml` is **generated** from the suffix-paired `baseline*.json`:

  ```bash
  python3 .github/scripts/check_policies.py
  ```

  Never hand-edit generated core-network policy templates. CI fails if a template drifts from its paired JSON document.

Every policy — the `infra/` baselines, and the inline snippets in `policy/*.md` — must pass the pre-merge checks:

```bash
python3 .github/scripts/check_policies.py
```

### `policy/` ships snippets, not full policies

A **snippet** is a fragment — one array element, or one array — illustrative and not deployable alone. It lives inline in the markdown, next to the prose that explains it, and it is the *only* form of JSON `policy/` contains.

`policy/` deliberately ships **no complete, deployable policy documents** of its own. The only full policies in this repository are the `infra/<pattern>/baseline*.json` files, and those exist to make a pattern deploy a working network or to complete a documented staged deployment, not to demonstrate a capability. Two things follow from that:

- A user's real requirement is not one of a fixed set. Composing a use case out of the capabilities on these pages, in the order [`SKILLS.md`](SKILLS.md) lays out, is what scales — a library of example policies does not, because there is always a combination of segments, sharing, service insertion and routing policies that the library does not have and never will.
- The generator capability in [`SKILLS.md`](SKILLS.md) is what turns a use case into a full document: it is the logic that assembles snippets in the right order, checks the constraints that bite, and hands back a validated policy. **That is where end-to-end policy composition lives** — not in a static file checked into this directory.

This was tried the other way once — a `policy/examples/` directory of complete deployable documents, admissible only when a snippet could not convey the interaction — and it was removed. The bar sounded principled but did not hold up: `check_policies.py` never deploys anything (CI is entirely static, see section 9), so "deployable" only ever meant a document a human deployed once and then checked into the repository as a claim nobody re-verifies. That is a weak guarantee for a policy that looks increasingly like curated content rather than composable teaching. If a genuinely undocumented interaction turns up — something a correctly-composed snippet still gets wrong — track it as an issue rather than a file; the fix belongs in the constraint checklist in [`SKILLS.md`](SKILLS.md#3-constraint-checklist), which is what feeds every future policy the generator builds, not in a document only that one interaction benefits from.

## 7. CloudFormation / Terraform parity policy

Every `infra/` pattern ships **both** a CloudFormation and a Terraform implementation of its core network and its workloads. There is currently no exception.

Where a capability is optional because its prerequisites are not something the pattern can provision for you — the Site-to-Site VPN and Direct Connect gateway attachments in [`4-hybrid`](infra/4-hybrid/), which need a BGP peer and a real Direct Connect circuit — both tools still express it. Terraform uses optional-object variables; CloudFormation uses a separate template you deploy only once you have the prerequisite. The policy side is identical either way.

Never claim an implementation that is not on disk. The human and agent-facing catalogs must remain synchronized; follow [Catalog and agent-index synchronization](#catalog-and-agent-index-synchronization) whenever a pattern changes.

## 8. Security-scan baseline & suppression mechanism

CI runs [Checkov](https://www.checkov.io/) over the repository using the committed [`.checkov.yaml`](.checkov.yaml) baseline at the repo root. These blueprints are intentionally minimal teaching examples, so some findings map to deliberate demo simplifications (open egress, EC2 instances without instance profiles, short log retention) or to confirmed false positives (SSH ingress that is actually scoped to the EC2 Instance Connect security group).

Checkov findings are advisory rather than a merge gate. The unprivileged CI workflow uploads a JSON report, and the separate [`Checkov PR report`](.github/workflows/checkov-pr-comment.yml) workflow updates one bounded PR comment recommending that applicable findings be fixed before merge. The reporter runs with `pull-requests: write` in the trusted default-branch context, so it must never check out or execute pull-request content. Its downloaded artifact is untrusted data: parse only the fixed JSON report, enforce size and display limits, and escape values before rendering them.

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

## 9. CI-aligned repository checks

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) and [`.pre-commit-config.yaml`](.pre-commit-config.yaml) align the repository's domain checks so contributors can reproduce most CI failures locally. They are not identical execution environments: pre-commit adds local hygiene hooks, host-installed tools are not pinned by the hook configuration, and CI defines which findings are blocking. When a check or version has a counterpart in both files, keep those counterparts synchronized.

| Check | CI job | pre-commit hook | Pinned version | Blocking in CI |
|-------|--------|-----------------|----------------|----------------|
| Terraform formatting | `fmt` | `terraform_fmt` | Terraform `1.9.8` | yes |
| Terraform validate | `terraform-checks` | `terraform_validate` | Terraform `1.9.8` | yes |
| Terraform lint | `tflint` | `terraform_tflint` | tflint `v0.61.0`, AWS ruleset `0.42.0` | yes |
| CloudFormation lint | `cfn-lint` | `cfn-lint` | cfn-lint `1.54.0` | yes |
| Generated README drift | `terraform-docs` | `terraform_docs` | terraform-docs `v0.21.0` | yes |
| Policy checks (baseline structure, snippets, generated CFN drift) | `policy` | `check-policies` | repo script; PyYAML `6.0.2` | yes |
| Markdown links | `markdown-links` | `lychee` (local hook) | CI action `v2`; local host binary | yes |
| IaC security scan | `checkov` | `checkov` | checkov `3.2.500` | **no** (`soft_fail: true`) |

Notes:

- Everything is **static**. No job configures AWS credentials, initializes a state backend, or creates a resource. `terraform validate` runs behind `terraform init -backend=false`.
- Pre-commit additionally runs repository-hygiene hooks such as trailing-whitespace, end-of-file, merge-conflict, YAML, and JSON checks. CI is authoritative for blocking behavior; for example, Checkov is currently non-blocking in CI even though its local hook reports findings.
- The `discover` job **enumerates pattern directories automatically** by globbing `infra/` for `*.tf` and `cloudformation/*.yaml`. Adding or restructuring patterns does not require editing the workflow — which is what made the v2 migration possible without rewriting CI.
- The `policy` job and `check-policies` pre-commit hook run `.github/scripts/check_policies.py`. Its only external dependency is PyYAML, needed to read the CloudFormation templates. CI installs PyYAML `6.0.2`; because the pre-commit hook uses `language: system`, contributors must install the same version in their host Python environment.
- `checkov` is non-blocking for findings. It uploads `checkov-results.json`, and the separate trusted `Checkov PR report` workflow publishes or updates the advisory PR comment. The reporter is asynchronous and is not part of the `ci-passed` branch-protection gate.
- `ci-passed` is an aggregator job that depends on every other job. Configure **only** that check in branch protection. If you add a new top-level job, add it to `ci-passed`'s `needs` list.
- Version pins in the table are deliberate. For host-installed tools, use the CI version documented in [`CONTRIBUTING.md`](CONTRIBUTING.md) when reproducible local parity matters. The sibling [Amazon VPC Lattice Blueprints](https://github.com/aws-samples/amazon-vpc-lattice-blueprints) repository runs the same pipeline shape; when raising a shared tool version, prefer raising it in both.

Run the checks locally before opening a pull request:

```bash
pip install pre-commit
python3 -m pip install "pyyaml==6.0.2"
pre-commit install
pre-commit run --all-files
```

The Terraform, tflint, terraform-docs, and lychee hooks shell out to locally installed binaries. The `check-policies` hook also uses host `python3` with PyYAML `6.0.2`. cfn-lint and Checkov are installed automatically by pre-commit into isolated hook environments.
