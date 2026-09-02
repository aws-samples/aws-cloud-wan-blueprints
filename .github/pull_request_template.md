## Description

<!-- What does this change do, and why? Link any related issue with "Closes #123". -->

## Where is the change?

<!-- Check every area this PR touches, then complete the matching section(s) below. -->

- [ ] `infra/` — a deployable infrastructure pattern
- [ ] `policy/` — a policy capability page or its snippets
- [ ] `guidance/` — a **new** scenario deep-dive page
- [ ] `guidance/` — an **update** to an existing deep-dive page
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

## If the change adds a new `guidance/` page

- [ ] The page passes the four-part admission test in [CONVENTIONS.md](../CONVENTIONS.md#guidance-ships-scenario-deep-dives-admitted-by-a-four-part-test): it answers a scenario question, composes two or more `policy/` capability pages (or knowledge outside the policy document), is not reducible to a constraint-checklist line, and links to mechanisms rather than restating them.
- [ ] The page is exactly one file, started from `guidance/.template.md`, opening with the **Applies when / Composes / Test on** routing block; any diagrams are in `images/` prefixed `guidance_<page_name>_` with the editable source added to `images/architectures.drawio`.
- [ ] The routing indexes are updated in this same change: the catalog row in `guidance/README.md` and the entry in `llms.txt`. Both describe the page in the requirement's vocabulary, and the catalog row's *Applies when* matches the page's own routing block.
- [ ] `SKILLS.md` was **not** edited to reference the page — it routes through the catalog by design.
- [ ] Examples remain composable snippets — no complete deployable policy documents — and fenced JSON parses (`python3 .github/scripts/check_policies.py`).

## If the change updates an existing `guidance/` page

- [ ] The page still satisfies the [admission test](../CONVENTIONS.md#guidance-ships-scenario-deep-dives-admitted-by-a-four-part-test): anything added is scenario reasoning, not a mechanism a `policy/` page owns or a rule that belongs in the `SKILLS.md` constraint checklist.
- [ ] Facts still live in one place: new content links to the capability pages rather than restating what they own, and any new AWS-documented behaviour cites its source.
- [ ] If the scope changed — the routing block's **Applies when**, **Composes**, or **Test on** — the catalog row in `guidance/README.md` and the `llms.txt` entry were updated to match.
- [ ] If headings were renamed, added, or removed, every cross-reference still resolves (the lychee hook checks in-page anchors too), and no other page linked to a heading that no longer exists.
- [ ] Still one file, snippets only, and fenced JSON parses (`python3 .github/scripts/check_policies.py`); any new or renamed diagram keeps the `images/guidance_<page_name>_` prefix with its source in `images/architectures.drawio`.
- [ ] `SKILLS.md` was **not** edited to reference the page.

## If the change is in `SKILLS.md`

- [ ] New content respects the skill's own rules: it sits on the correct side of the knowledge/procedure seam (see *Telling the two halves apart*), and any intake change keeps the tier tags and flag-report behaviour consistent.
- [ ] The skill still agrees with the repository: the *How to use this skill* routing table and section anchors resolve, and shared facts (pattern catalogs, association contract, policy version) match `infra/` and `policy/`.
- [ ] I piloted the change with an agent — gave it the updated `SKILLS.md` and a representative question or generation request — and its behaviour matched the intent. Describe the pilot under **Testing**.

## Testing

<!-- How was this verified? If a pattern was deployed, say in which Regions and what was checked (segment associations, route tables, connectivity tests). If it was only statically validated, say so. If SKILLS.md changed, describe the agent pilot: the prompt, the model/agent used, and what the response got right. -->
