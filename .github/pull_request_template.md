## Description

<!-- What does this change do, and why? Link any related issue with "Closes #123". -->

## Where is the change?

<!-- Check every area this PR touches, then complete the matching section(s) below. -->

- [ ] `infra/` — a deployable infrastructure pattern
- [ ] `policy/` — a policy capability page or its snippets
- [ ] `SKILLS.md` — agent knowledge or generator logic

## Checklist for every change

<!-- CI enforces most of this automatically. Running the checks locally first is faster than round-tripping through CI. -->

- [ ] I have read [CONVENTIONS.md](../CONVENTIONS.md) and this change conforms to it.
- [ ] `pre-commit run --all-files` passes locally (see [CONTRIBUTING.md](../CONTRIBUTING.md)).
- [ ] I reviewed advisory Checkov findings, fixed applicable issues, and included a justification for every new suppression (baseline comment or inline `:reason`).

## If the change is in `infra/`

<!-- Formatting, generated READMEs, and generated CloudFormation drift are already enforced by the pre-commit suite above — no separate checkboxes needed. -->

- [ ] CloudFormation and Terraform implementations are in parity, and the pattern is still defined only by the attachment types it creates — it does not encode a use case.
- [ ] Human and agent indexes agree: `infra/README.md` and the `SKILLS.md` infrastructure selector reflect this change, and the tags the IaC applies still match what the baseline policy's `attachment-policies` expect.
- [ ] Every new IaC source file carries the MIT-0 license header.
- [ ] The pattern README's **Cost** and **Cleanup** sections reflect any resource changes.

## If the change is in `policy/`

- [ ] Examples remain composable snippets — no complete deployable policy documents were added.
- [ ] The capability indexes agree: `policy/README.md` and the `SKILLS.md` capability-page and assembly-order tables both reflect this change.
- [ ] Any new constraint or caveat is also reflected in `SKILLS.md` (*Constraints that bite* and the constraint checklist), with a link to the AWS documentation that states it.
- [ ] Fenced JSON snippets parse (`python3 .github/scripts/check_policies.py`).

## If the change is in `SKILLS.md`

- [ ] New content respects the skill's own rules: it sits on the correct side of the knowledge/procedure seam (see *Telling the two halves apart*), and any intake change keeps the tier tags and flag-report behaviour consistent.
- [ ] The skill still agrees with the repository: the *How to use this skill* routing table and section anchors resolve, and shared facts (pattern catalogs, association contract, policy version) match `infra/` and `policy/`.
- [ ] I piloted the change with an agent — gave it the updated `SKILLS.md` and a representative question or generation request — and its behaviour matched the intent. Describe the pilot under **Testing**.

## Testing

<!-- How was this verified? If a pattern was deployed, say in which Regions and what was checked (segment associations, route tables, connectivity tests). If it was only statically validated, say so. If SKILLS.md changed, describe the agent pilot: the prompt, the model/agent used, and what the response got right. -->
