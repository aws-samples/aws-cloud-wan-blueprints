---
title: "AWS Cloud WAN scenario deep dives: design guidance that composes multiple policy capabilities"
description: "Deep-dive design guidance for specific AWS Cloud WAN scenarios whose answer spans several network-policy capabilities. The catalog maps each page to the requirement it answers, the policy capability pages it composes, and the infrastructure pattern to test it on."
---

# Scenario deep dives

This section holds **cross-capability design reasoning**: pages that answer a specific scenario question — "how do I achieve X" — whose answer composes two or more [`policy/`](../policy/) capability pages, or requires knowledge outside the policy document itself, such as BGP path selection or Direct Connect behavior. A capability page explains one area of the policy JSON; a guidance page explains how several of them combine into a known design.

These pages are deliberately rare, so the catalog below being short is the design working. Most questions are answered by a single [`policy/`](../policy/) page, and most traps reduce to a line in the [`SKILLS.md` constraint checklist](../SKILLS.md#3-constraint-checklist) — a guidance page exists only where neither is enough. If nothing here matches your requirement, build from the capability pages.

Like `policy/`, guidance pages ship **composable snippets, not complete deployable policies**. A page teaches the reasoning and links to the capability pages for each mechanism; it never restates what a capability page owns.

## Catalog

This table is the routing index: match your requirement against the *Applies when* column. AI agents following [`SKILLS.md`](../SKILLS.md) scan this catalog before assembling a policy, so each entry's *Applies when* phrases are written in the vocabulary of the requirement, not of the policy document.

| Page | Applies when | Composes | Test on |
|------|--------------|----------|---------|
| [`dx_geographic_egress.md`](./dx_geographic_egress.md) | "Hot-potato routing" — leave the AWS backbone as close to the source as possible; on-premises announces the same routes from several geographic areas; one Direct Connect gateway per geography; prefer the same-geography Direct Connect with failover to another geography; rank areas active / passive-1 / passive-2 | [`7-routing_policies.md`](../policy/7-routing_policies.md), [`9-attachment_routing_policy_rules.md`](../policy/9-attachment_routing_policy_rules.md) | [`4-hybrid`](../infra/4-hybrid/) (needs a second Direct Connect gateway and two geographies) |

To contribute a page, start from [`.template.md`](./.template.md) and follow the guidance rules in [`CONVENTIONS.md`](../CONVENTIONS.md#guidance-ships-scenario-deep-dives-admitted-by-a-four-part-test) — the admission test, the page format, and the indexes to update all live there.
