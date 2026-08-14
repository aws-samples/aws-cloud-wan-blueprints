## Description

<!-- What does this change do, and why? Link any related issue with "Closes #123". -->

## Type of change

- [ ] New pattern
- [ ] Change to an existing pattern
- [ ] Documentation only
- [ ] Repository tooling (CI, pre-commit, linter configuration)
- [ ] Bug fix

## Checklist

<!-- The CI workflow enforces most of this automatically. Running the checks
     locally first is faster than round-tripping through CI. -->

- [ ] I have read [CONVENTIONS.md](../CONVENTIONS.md) and this change conforms to it.
- [ ] `pre-commit run --all-files` passes locally (see [CONTRIBUTING.md](../CONTRIBUTING.md)).
- [ ] Terraform is canonically formatted (`terraform fmt -recursive`).
- [ ] Generated Terraform READMEs were regenerated, not hand-edited
      (`terraform-docs --config .config/.terraform-docs.yaml <dir>`).
- [ ] Every new IaC source file carries the MIT-0 license header.
- [ ] I reviewed advisory Checkov findings, fixed applicable issues, and included a
      justification for every new suppression (baseline comment or inline `:reason`).

## For new or changed patterns

- [ ] CloudFormation and Terraform implementations are in parity.
- [ ] Pattern catalogs in `README.md`, `infra/README.md`, and the `SKILLS.md`
      infrastructure selector are updated so human and agent indexes agree.
- [ ] The Cloud WAN network policy shown in the docs matches the policy the IaC
      actually deploys.

## For changed policy capability pages

- [ ] Policy indexes in `README.md`, `policy/README.md`, and `SKILLS.md` are
      updated, including the assembly order and any affected constraints.

## Testing

<!-- How was this verified? If the pattern was deployed, say in which regions
     and what was checked (segment associations, route tables, connectivity
     tests). If it was only statically validated, say so. -->
