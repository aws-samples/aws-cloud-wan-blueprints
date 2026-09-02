# Contributing Guidelines

Thank you for your interest in contributing to our project. Whether it's a bug report, new feature, correction, or additional documentation, we greatly value feedback and contributions from our community.

Please read through this document before submitting any issues or pull requests to ensure we have all the necessary information to effectively respond to your bug report or contribution.

## Repository conventions

Every published pattern follows a single set of conventions covering naming, directory layout, dependency version pins, license headers, Cloud WAN network-policy authoring, and CloudFormation/Terraform parity. Before adding or modifying a pattern, a `policy/` capability page, or a `guidance/` scenario deep dive, read [CONVENTIONS.md](CONVENTIONS.md), it is the contract contributions must follow — including the admission test that decides whether a scenario qualifies for `guidance/` at all. Pull requests are expected to conform to it.

## Reporting bugs, feature requests, and generated-policy issues

We welcome you to use the GitHub issue tracker to report bugs, suggest features, or report unexpected policy output from an AI agent using [`SKILLS.md`](SKILLS.md). When filing an issue, please check existing open or recently closed issues to make sure somebody else has not already reported it. Please include as much relevant information as you can. Details like these are especially useful:

- A reproducible test case or series of steps
- The version of our code being used
- Any modifications you made that are relevant to the issue
- Anything unusual about your environment or deployment

For unexpected generated policy output, use the [Unexpected generated policy template](.github/ISSUE_TEMPLATE/unexpected_policy_output.md). Include the original prompt, complete generated policy, and either the expected policy or precise comments describing the mismatch. Include the agent/model and `SKILLS.md` revision when known. Redact credentials, account or customer identifiers, private endpoints, and confidential data. Report potential vulnerabilities through the [security process](#security-issue-notifications), not a public issue.

## Contributing via Pull Requests

Contributions via pull requests are much appreciated. Before sending us a pull request, please ensure that:

1. You are working against the latest source on the _main_ branch.
2. You check existing open, and recently merged, pull requests to make sure someone else hasn't addressed the problem already.
3. Ensure local checks pass. Run `pre-commit run --all-files` before opening a PR so the CI-aligned static checks are green locally — see [Local checks (pre-commit)](#local-checks-pre-commit) for setup and required tools.
4. You open an issue to discuss any significant work - we would hate for your time to be wasted.

To send us a pull request, please:

1. Fork the repository.
2. Modify the source; please focus on the specific change you are contributing. If you also reformat all the code, it will be hard for us to focus on your change.
3. Ensure local checks pass.
4. Commit to your fork using clear commit messages.
5. Send us a pull request, answering any default questions in the pull request interface.
6. Pay attention to any automated CI failures reported in the pull request, and stay involved in the conversation.

GitHub provides additional documentation on [forking a repository](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo) and [creating a pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request).

## Local checks (pre-commit)

This repository ships a [`pre-commit`](https://pre-commit.com/) configuration ([`.pre-commit-config.yaml`](.pre-commit-config.yaml)) aligned with the **static** domain checks run in CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)), so you can catch and fix most issues locally before pushing instead of round-tripping through CI. Pre-commit also runs local repository-hygiene checks, while CI remains authoritative for which findings are blocking. Together, the checks enforce the repository conventions in [CONVENTIONS.md](CONVENTIONS.md) (formatting, linting, generated-doc drift, link health, and security scanning).

On pull requests, Checkov remains advisory. CI uploads its machine-readable findings, and the trusted [`Checkov PR report`](.github/workflows/checkov-pr-comment.yml) workflow creates or updates one PR comment with a bounded summary. Review and resolve applicable findings before merge. If a finding is an intentional blueprint simplification or confirmed false positive, document the suppression and its justification according to [CONVENTIONS.md](CONVENTIONS.md#8-security-scan-baseline--suppression-mechanism).

All hooks are **static**: they need **no AWS credentials** and provision nothing. Terraform validation runs `terraform init -backend=false` followed by `terraform validate`, so no remote state backend or cloud access is involved.

### Required local tools

Use the versions CI documents when reproducible local parity matters. `cfn-lint` and `checkov` are installed automatically by `pre-commit` into isolated hook environments from the revisions pinned in `.pre-commit-config.yaml`; you only need them standalone if you want to run those linters directly. The remaining hooks use host/`system` tools. Install `terraform`, `tflint`, `terraform-docs`, and `lychee` yourself, and keep them aligned with the documented CI versions where one is specified. The `check-policies` hook also uses host `python3` and requires PyYAML; install the CI-pinned version listed below.

| Tool | Version (matches CI) | Used for | Install |
|------|----------------------|----------|---------|
| [`pre-commit`](https://pre-commit.com/#install) | >= 3.5.0 | The hook runner itself | `pip install pre-commit` (or `brew install pre-commit`) |
| [PyYAML](https://pyyaml.org/) | `6.0.2` | Parse CloudFormation templates in the local `check-policies` hook | `python3 -m pip install "pyyaml==6.0.2"` |
| [Terraform](https://developer.hashicorp.com/terraform/install) | CI uses `1.9.8`; configs require `>= 1.3.0` | `terraform fmt` / `terraform validate` | Official installer, or `brew install terraform` |
| [tflint](https://github.com/terraform-linters/tflint) | CI uses `v0.61.0` (AWS ruleset `0.42.0`, pinned in [`.tflint.hcl`](.tflint.hcl)) | Terraform lint (AWS ruleset) | `brew install tflint`, or see the [install docs](https://github.com/terraform-linters/tflint#installation) |
| [terraform-docs](https://terraform-docs.io/user-guide/installation/) | CI uses `v0.21.0` | Generated-README drift check | `brew install terraform-docs` |
| [cfn-lint](https://github.com/aws-cloudformation/cfn-lint) | `1.54.0` | CloudFormation lint (standalone use; otherwise auto-installed by pre-commit) | `pip install "cfn-lint==1.54.0"` |
| [checkov](https://www.checkov.io/2.Basics/Installing%20Checkov.html) | `~3.2.x` (pre-commit pins `3.2.500`) | Static IaC security scan (standalone use; otherwise auto-installed by pre-commit) | `pip install checkov` |
| [lychee](https://github.com/lycheeverse/lychee) | latest | Markdown link check (required by the local `lychee` hook) | `brew install lychee`, or `cargo install lychee` |

> The AWS tflint ruleset (`0.42.0`) is installed by `tflint --init`, which `pre-commit` runs for you via the Terraform hooks.

### Install and run

```bash
# 1. Install the runner and the static policy checker's Python dependency.
pip install pre-commit
python3 -m pip install "pyyaml==6.0.2"

# 2. Install the git hook so checks run automatically on `git commit`.
pre-commit install

# 3. Run every check across the whole repository (do this before opening a PR).
pre-commit run --all-files
```

`pre-commit install` wires the hooks into your local git so the relevant checks run on each `git commit`. To run all checks on demand (including on files you have not staged), use `pre-commit run --all-files`.

You can also run a single hook by id, for example:

```bash
pre-commit run terraform_fmt --all-files       # formatting only
pre-commit run terraform_validate --all-files  # init -backend=false + validate
pre-commit run terraform_tflint --all-files    # tflint (AWS ruleset)
pre-commit run terraform_docs --all-files      # generated-README drift
pre-commit run cfn-lint --all-files            # CloudFormation lint
pre-commit run checkov --all-files             # security scan
pre-commit run check-policies --all-files      # policy structure, snippets, and generated CFN drift
pre-commit run lychee --all-files              # markdown link check
```

### Regenerating a Terraform README

Each pattern's `terraform/README.md` is generated by terraform-docs from that directory's `.header.md` plus its variables and outputs. **Never hand-edit the generated README.** Edit `.header.md`, then regenerate:

```bash
terraform-docs --config .config/.terraform-docs.yaml infra/<pattern>/terraform
```

**Generation is environment-independent**, so it does not matter whether the directory has been initialized with `terraform init`. That is why [`.config/.terraform-docs.yaml`](.config/.terraform-docs.yaml) hides the **Providers** section: terraform-docs sources it from `.terraform/` when that directory exists, which would put resolved versions (`1.95.0`) in a locally generated README and version constraints (`>= 1.67.0`) in the CI-generated one. The **Requirements** section carries the constraints from `required_providers` either way, so nothing is lost. If you add a section to the config, check that its content comes from the code and not from local state.

The `terraform-docs` CI job fails if any generated README has drifted from its source.

### Keeping CI and pre-commit aligned

The local pre-commit setup and CI provide two views of the repository's **domain checks**: Terraform formatting and validation, tflint, terraform-docs drift, cfn-lint, Checkov, Cloud WAN policy checks, and Markdown links. Pre-commit additionally runs local hygiene hooks, host-tool versions are managed outside the hook configuration, and CI determines whether a finding is blocking. Running `pre-commit run --all-files` is therefore the fastest local signal, but CI remains authoritative.

**Maintenance expectation (checked in review):** when a check or tool version has a counterpart in both [`.pre-commit-config.yaml`](.pre-commit-config.yaml) and [`.github/workflows/ci.yml`](.github/workflows/ci.yml), update both in the same change. For example:

- **Adding or removing a shared domain check** — add or remove the matching hook and CI job/step. If you add a new top-level CI job, also add it to the `needs` list of the `ci-passed` aggregator, which is the single check configured in branch protection. Local-only hygiene hooks do not need CI counterparts.
- **Bumping a tool version** — keep counterpart versions aligned where both environments pin the tool. Update the hook `rev:` or pinned dependency in `.pre-commit-config.yaml`, the corresponding CI pin, and the version table in [Required local tools](#required-local-tools). For host-installed tools, update the documented CI version even though pre-commit cannot enforce the local binary version.
- **Changing Checkov reporting** — keep the JSON artifact contract in `ci.yml` and the parser/comment behavior in `checkov-pr-comment.yml` compatible. The reporter is privileged: it must never check out or execute pull-request content, and it must continue treating the downloaded report as untrusted data.

A pull request that changes only one side of an existing counterpart should be flagged in review.

#### Shared single-source-of-truth config

Some configuration is **not** duplicated (both pre-commit and CI read the same files), so editing one of these automatically affects both local and CI runs (no mirroring needed, but be aware the change is repo-wide):

- [`.tflint.hcl`](.tflint.hcl) — tflint rules and the pinned AWS ruleset version.
- [`.checkov.yaml`](.checkov.yaml) — checkov scan scope, frameworks, and suppressions.
- [`.config/.terraform-docs.yaml`](.config/.terraform-docs.yaml) — terraform-docs output config used for the generated-README drift check.

Because these are shared, a change to any of them takes effect in both places at once. The alignment rule above applies only to checks and versions that have counterparts declared in both `.pre-commit-config.yaml` and `.github/workflows/ci.yml`.

## Finding contributions to work on

Looking at the existing issues is a great way to find something to contribute on. As our projects, by default, use the default GitHub issue labels (enhancement/bug/duplicate/help wanted/invalid/question/wontfix), looking at any 'help wanted' issues is a great place to start.

## Code of Conduct

This project has adopted the [Amazon Open Source Code of Conduct](https://aws.github.io/code-of-conduct). For more information see the [Code of Conduct FAQ](https://aws.github.io/code-of-conduct-faq) or contact opensource-codeofconduct@amazon.com with any additional questions or comments.

## Security issue notifications

If you discover a potential security issue in this project we ask that you notify AWS/Amazon Security via our [vulnerability reporting page](http://aws.amazon.com/security/vulnerability-reporting/). Please do **not** create a public github issue.

## Licensing

See the [LICENSE](LICENSE) file for our project's licensing. We will ask you to confirm the licensing of your contribution.
