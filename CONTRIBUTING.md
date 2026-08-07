# Contributing Guidelines

Thank you for your interest in contributing to our project. Whether it's a bug report, new feature, correction, or additional documentation, we greatly value feedback and contributions from our community.

Please read through this document before submitting any issues or pull requests to ensure we have all the necessary information to effectively respond to your bug report or contribution.

## Repository conventions

Every published pattern follows a single set of conventions covering naming, directory layout, dependency version pins, license headers, Cloud WAN network-policy authoring, and CloudFormation/Terraform parity. Before adding or modifying a pattern, read [CONVENTIONS.md](CONVENTIONS.md), it is the contract new patterns must follow. Pull requests are expected to conform to it.

## Reporting Bugs/Feature Requests

We welcome you to use the GitHub issue tracker to report bugs or suggest features. When filing an issue, please check existing open, or recently closed, issues to make sure somebody else hasn't already reported the issue. Please try to include as much information as you can. Details like these are incredibly useful:

- A reproducible test case or series of steps
- The version of our code being used
- Any modifications you've made relevant to the bug
- Anything unusual about your environment or deployment

## Contributing via Pull Requests

Contributions via pull requests are much appreciated. Before sending us a pull request, please ensure that:

1. You are working against the latest source on the _main_ branch.
2. You check existing open, and recently merged, pull requests to make sure someone else hasn't addressed the problem already.
3. Ensure local checks pass. Run `pre-commit run --all-files` before opening a PR so the same static checks CI runs are green locally — see [Local checks (pre-commit)](#local-checks-pre-commit) for setup and required tools.
4. You open an issue to discuss any significant work - we would hate for your time to be wasted.

To send us a pull request, please:

1. Fork the repository.
2. Modify the source; please focus on the specific change you are contributing. If you also reformat all the code, it will be hard for us to focus on your change.
3. Ensure local checks pass.
4. Commit to your fork using clear commit messages.
5. Send us a pull request, answering any default questions in the pull request interface.
6. Pay attention to any automated CI failures reported in the pull request, and stay involved in the conversation.

GitHub provides additional document on [forking a repository](https://help.github.com/articles/fork-a-repo/) and [creating a pull request](https://help.github.com/articles/creating-a-pull-request/).

## Local checks (pre-commit)

This repository ships a [`pre-commit`](https://pre-commit.com/) configuration ([`.pre-commit-config.yaml`](.pre-commit-config.yaml)) that mirrors the **static** checks run in CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)), so you can catch and fix issues locally before pushing instead of round-tripping through CI. The checks enforce the repository conventions in [CONVENTIONS.md](CONVENTIONS.md) (formatting, linting, generated-doc drift, link health, and a security scan).

All hooks are **static**: they need **no AWS credentials** and provision nothing. Terraform validation runs `terraform init -backend=false` followed by `terraform validate`, so no remote state backend or cloud access is involved.

### Required local tools

Pin your local tools to the versions CI uses so local results match CI. `cfn-lint` and `checkov` are installed automatically by `pre-commit` into isolated hook environments from the revisions pinned in `.pre-commit-config.yaml`; you only need them standalone if you want to run those linters directly. The remaining tools (`terraform`, `tflint`, `terraform-docs`, and `lychee`) are host/`system` tools that the hooks shell out to, so you must install them yourself.

| Tool | Version (matches CI) | Used for | Install |
|------|----------------------|----------|---------|
| [`pre-commit`](https://pre-commit.com/#install) | >= 3.5.0 | The hook runner itself | `pip install pre-commit` (or `brew install pre-commit`) |
| [Terraform](https://developer.hashicorp.com/terraform/install) | CI uses `1.9.8`; configs require `>= 1.3.0` | `terraform fmt` / `terraform validate` | Official installer, or `brew install terraform` |
| [tflint](https://github.com/terraform-linters/tflint) | CI uses `v0.61.0` (AWS ruleset `0.42.0`, pinned in [`.tflint.hcl`](.tflint.hcl)) | Terraform lint (AWS ruleset) | `brew install tflint`, or see the [install docs](https://github.com/terraform-linters/tflint#installation) |
| [terraform-docs](https://terraform-docs.io/user-guide/installation/) | CI uses `v0.21.0` | Generated-README drift check | `brew install terraform-docs` |
| [cfn-lint](https://github.com/aws-cloudformation/cfn-lint) | `1.46.0` | CloudFormation lint (standalone use; otherwise auto-installed by pre-commit) | `pip install "cfn-lint==1.46.0"` |
| [checkov](https://www.checkov.io/2.Basics/Installing%20Checkov.html) | `~3.2.x` (pre-commit pins `3.2.500`) | Static IaC security scan (standalone use; otherwise auto-installed by pre-commit) | `pip install checkov` |
| [lychee](https://github.com/lycheeverse/lychee) | latest | Markdown link check (required by the local `lychee` hook) | `brew install lychee`, or `cargo install lychee` |

> The AWS tflint ruleset (`0.42.0`) is installed by `tflint --init`, which `pre-commit` runs for you via the Terraform hooks.

### Install and run

```bash
# 1. Install the runner.
pip install pre-commit

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
pre-commit run lychee --all-files              # markdown link check
```

### Regenerating a Terraform README

Each pattern's `terraform/README.md` is generated by terraform-docs from that directory's `.header.md` plus its variables and outputs. **Never hand-edit the generated README.** Edit `.header.md`, then regenerate:

```bash
terraform-docs --config .config/.terraform-docs.yaml infra/<pattern>/terraform
```

The `terraform-docs` CI job fails if any generated README has drifted from its source.

### Keeping CI and pre-commit in lockstep

The local pre-commit setup and CI are intentionally two views of the **same** static checks. [`.pre-commit-config.yaml`](.pre-commit-config.yaml) and [`.github/workflows/ci.yml`](.github/workflows/ci.yml) are meant to mirror each other: the same checks (`terraform fmt`, `terraform validate`, `tflint`, `terraform-docs` drift, `cfn-lint`, `checkov`, and the markdown link check), run with the same tools, pinned to the same versions. This is what lets `pre-commit run --all-files` predict the CI result.

**Maintenance expectation (checked in review):** when you change one side, you MUST make the equivalent change on the other so local and CI stay consistent. For example:

- **Adding or removing a check** — add/remove the matching hook in `.pre-commit-config.yaml` *and* the matching job/step in `.github/workflows/ci.yml`. If you add a new top-level CI job, also add it to the `needs` list of the `ci-passed` aggregator, which is the single check configured in branch protection.
- **Bumping a tool version** — keep the versions aligned on both sides. That means the hook `rev:`/pinned versions in `.pre-commit-config.yaml` (e.g. `cfn-lint` `v1.46.0`, `checkov` `3.2.500`) and the corresponding pins in `.github/workflows/ci.yml` (e.g. `terraform_version`, `tflint_version`, `pip install "cfn-lint==..."`, `terraform-docs` version) **and** the version table in the [Required local tools](#required-local-tools) section above.

A pull request that changes one side without the other should be flagged in review.

#### Shared single-source-of-truth config

Some configuration is **not** duplicated (both pre-commit and CI read the same files), so editing one of these automatically affects both local and CI runs (no mirroring needed, but be aware the change is repo-wide):

- [`.tflint.hcl`](.tflint.hcl) — tflint rules and the pinned AWS ruleset version.
- [`.checkov.yaml`](.checkov.yaml) — checkov scan scope, frameworks, and suppressions.
- [`.config/.terraform-docs.yaml`](.config/.terraform-docs.yaml) — terraform-docs output config used for the generated-README drift check.

Because these are shared, a change to any of them takes effect in both places at once. The mirroring rule above applies to the checks and tool versions declared *in* `.pre-commit-config.yaml` and `.github/workflows/ci.yml` themselves.

## Finding contributions to work on

Looking at the existing issues is a great way to find something to contribute on. As our projects, by default, use the default GitHub issue labels (enhancement/bug/duplicate/help wanted/invalid/question/wontfix), looking at any 'help wanted' issues is a great place to start.

## Code of Conduct

This project has adopted the [Amazon Open Source Code of Conduct](https://aws.github.io/code-of-conduct). For more information see the [Code of Conduct FAQ](https://aws.github.io/code-of-conduct-faq) or contact opensource-codeofconduct@amazon.com with any additional questions or comments.

## Security issue notifications

If you discover a potential security issue in this project we ask that you notify AWS/Amazon Security via our [vulnerability reporting page](http://aws.amazon.com/security/vulnerability-reporting/). Please do **not** create a public github issue.

## Licensing

See the [LICENSE](LICENSE) file for our project's licensing. We will ask you to confirm the licensing of your contribution.
