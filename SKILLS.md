# AWS Cloud WAN Skill

> **Purpose.** This file is written for an **AI agent** — if you are reading it yourself, start with the overview and catalog in [`README.md`](./README.md) instead. Drop this file into your agent's context (as a system/skill file, a retrieved document, or pasted reference) so the agent can reason correctly about **AWS Cloud WAN**: what it is, how its policy model works, when it is the right tool, how to design with it, and how to turn a user's requirement into a validated policy document.
>
> **Resolving this file's links.** This file ships inside the public [AWS Cloud WAN Blueprints repository](https://github.com/aws-samples/aws-cloud-wan-blueprints). If you have only this file, every relative link resolves under that repository — for example, `policy/4-segment_sharing.md` is `https://github.com/aws-samples/aws-cloud-wan-blueprints/blob/main/policy/4-segment_sharing.md`. Fetch the referenced pages from there when you can browse; if you cannot, say so and ask the user to provide them rather than answering from general knowledge.
>
> **Two capabilities, one skill.** This is a single skill with two halves. **Knowledge** — what Cloud WAN is and how to reason about it. **Generator** — the workflow that turns a stated requirement into a policy document, recommends where to deploy it, reviews or extends a policy the user already has, and says what a policy cannot express. They ship together because neither is much use alone: knowledge without the workflow leaves an agent improvising an assembly order, and the workflow without the knowledge leaves it assembling something it does not understand.

## How to use this skill

Match the request, then read only what it points at. You do not need to read this file end to end.

| The user is asking | Go to | Read |
|--------------------|-------|------|
| "What is Cloud WAN?", "how does it work?" | [What Cloud WAN is](#what-cloud-wan-is), [Core building blocks](#core-building-blocks), [The policy model](#the-policy-model-how-routing-behaviour-is-expressed) | Knowledge |
| "Should we use Cloud WAN?", "Cloud WAN or Transit Gateway?" | [When to use Cloud WAN](#when-to-use-cloud-wan) | Knowledge |
| "Design a global network for us" | [How to architect with Cloud WAN](#how-to-architect-with-cloud-wan), then [Constraints that bite](#constraints-that-bite) | Knowledge |
| "Build me a policy for *this* requirement" | [Building a policy](#building-a-policy) | Generator |
| "Why doesn't my policy work?", "review this policy" | [Troubleshooting and extending an existing policy](#7-troubleshooting-and-extending-an-existing-policy), backed by [Constraints that bite](#constraints-that-bite) | Both |
| "Make this policy also do X" | [Troubleshooting and extending an existing policy](#7-troubleshooting-and-extending-an-existing-policy) | Generator |
| "Where do I deploy this?" | [Choosing infrastructure](#5-choosing-infrastructure) | Generator |
| "Explain segments / sharing / inspection / route filtering" | the matching page in [`policy/`](./policy/) | Neither — send them to the capability pages |

Whatever the request, four rules always apply:

1. **Ground the mental model first.** Almost every Cloud WAN question is really a question about the policy document.
2. **Check fit before recommending it.** For a new multi-account network, Cloud WAN is the default recommendation. For an existing Transit Gateway network, recommend migrating only when a real trigger exists — see [When to use Cloud WAN](#when-to-use-cloud-wan).
3. **Never invent policy syntax.** If you are unsure whether a field, action, or match condition exists, say so and point at the [policy reference](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-change-sets.html) rather than guessing. Cloud WAN validates policy server-side and a wrong field is a hard failure, not a warning.
4. **The authoritative gate is Cloud WAN itself.** Creating a policy version produces a change set you must explicitly execute, so it is a real dry run against the actual state of the network. No offline check substitutes for it.

## Telling the two halves apart

If you are editing this file, the test for where a new fact belongs is: **would this still be true if this repository did not exist?**

- **Yes** → it is knowledge. It goes in part one, or in a [`policy/`](./policy/) capability page if it is about one array of the document.
- **No** → it is procedure. It goes in [Building a policy](#building-a-policy).

That line is what stops the two halves slowly learning each other's content. Constraints are knowledge and live in [Constraints that bite](#constraints-that-bite); the [constraint checklist](#3-constraint-checklist) exists to give them a *checking order*, not to restate them.

**If you would rather split this into two skills**, the seam is clean: everything above [How to use this repository](#how-to-use-this-repository) is the knowledge half, everything from there down — the repository guide and the generator — is the repository half, and the generator depends on the knowledge rather than the other way round. Load knowledge first.

---

## What Cloud WAN is

AWS Cloud WAN is a **managed, intent-driven service for building and operating a global network** across AWS Regions and on-premises environments. You describe the network you want in a single declarative **JSON network policy**, and Cloud WAN builds and maintains it: regional routers, the peering mesh between them, route tables, and the mapping of attachments into routing domains.

The key mental shift: with Transit Gateway you assemble a global network out of per-Region primitives, and you own the seams — TGW peerings, route table associations and propagations, static routes between Regions. With Cloud WAN you declare **segments** (global routing domains) and **rules**, and the seams are the service's problem. A segment exists in every Region where you have a router, and cross-Region routing between segment members is automatic via e-BGP.

Two things follow from the policy-driven model and are worth stating to users up front:

- **The policy is the system.** Changes are made by creating a new **policy version**, not by mutating resources one at a time. This gives you review and rollback, and it means "what is my network?" has a single, diffable answer.
- **Policy changes are staged, not immediate.** Creating a policy version generates a **change set** that Cloud WAN validates and that you then explicitly deploy. Nothing changes until you execute it. This is the closest thing Cloud WAN has to a dry run, and it is the right way to validate a generated policy.

---

## Core building blocks

Learn these seven constructs; almost every Cloud WAN design is a composition of them.

- **Global network** — the outermost container. Holds the core network plus (optionally) on-premises inventory for monitoring. One per organization is typical.
- **Core network** — the managed global network itself, defined entirely by its **network policy**. Contains the routers, segments, and routing behaviour.
- **Core network policy** — the declarative JSON document that defines everything: `core-network-configuration` (ASN ranges, edge locations, ECMP/DNS/security-group-referencing settings), `segments`, `network-function-groups`, `segment-actions`, `attachment-policies`, and `routing-policies`. Versioned, change-set-gated, diffable.
- **Core Network Edge (CNE)** — the regional router, conceptually similar to a Transit Gateway. One per Region you list as an `edge-location`. Highly available within the Region. CNEs are **automatically full-mesh peered** with each other and exchange routes via **e-BGP**, which is the single biggest operational difference from Transit Gateway. Each CNE gets an ASN from the `asn-ranges` you declare (or one you pin per edge location).
- **Segment** — a **global** routing domain: one route table replicated across every Region that has a CNE, analogous to a TGW route table or a VRF. Properties worth knowing:
  - Present in every CNE Region by default; can be restricted to a subset of Regions.
  - An attachment can belong to **exactly one** segment.
  - By default attachments in a segment can reach each other, and their prefixes propagate automatically.
  - `isolate-attachments: true` blocks attachment-to-attachment traffic *within* the segment. This is not just a security knob: **isolated mode is required for service insertion to work between attachments in the same segment**, because it is what stops traffic from bypassing the inspection path.
  - Common segmentation axes: environment (prod/dev/test), business unit, or geography.
- **Attachment** — the connection between a network resource and a CNE. Types: **VPC**, **Site-to-Site VPN**, **Direct Connect gateway**, **Transit Gateway route table** (the TGW-integration/migration path), and **Connect** (SD-WAN, GRE or tunnel-less, riding on an underlying VPC attachment). An attachment is associated with **either** a segment **or** a network function group — never both.
- **Attachment policy** — the rules that decide, automatically, which segment or NFG a new attachment lands in. Rules are numbered and evaluated in order, matching on **tags** (`tag-exists`, `tag-value`), **attachment type**, **AWS account ID**, or **Region**, and then acting via `association-method: tag | constant` or `add-to-network-function-group`. This is what makes Cloud WAN self-service: a workload team tags their VPC attachment and it joins the right routing domain with no central ticket.

---

## The policy model: how routing behaviour is expressed

Beyond plain intra-segment connectivity, all routing behaviour comes from three kinds of action.

### Segment sharing

```
action: share    →  leak routes between segments (1:1 or 1:many)
```

Makes two segments mutually reachable without inspection. **Non-transitive**: if A shares with B and B shares with C, A and C are *not* connected. You must declare each sharing relationship you want. This is the mechanism behind the classic "shared services" segment.

There is **no deny action**. Two segments that do not share are already unreachable to each other. When a user asks you to "block" traffic between segments, the answer is the *absence* of a share, not a rule.

### Service insertion

Routes traffic through a security appliance (commonly AWS Network Firewall, but any appliance works). Inspection attachments go into a **network function group (NFG)** rather than a segment. An NFG is a **global** construct, so it can serve cross-Region inspection.

| Action | Traffic | Meaning |
|--------|---------|---------|
| `send-to` | north-south | Send egress / internet-bound traffic to the appliance |
| `send-via` | east-west | Send traffic between attachments (intra- or inter-segment) through the appliance |

`send-via` takes a **mode**:

- **`dual-hop`** — cross-Region traffic is inspected in **both** the source and destination Regions. Requires an inspection attachment in **every Region** of the service-insertion-enabled segments.
- **`single-hop`** — traffic traverses **one** intermediate inspection attachment. Cloud WAN picks the Region from a default priority list; use `with-edge-overrides` to define explicitly which Region inspects each Region-pair. For a Region with no local inspection VPC, an edge override is how you send its traffic to the nearest Region that has one.

`when-sent-to` scopes a `send-via` to specific destination segments (or `*`).

### Routing policies

Fine-grained, BGP-level control, applied **inbound** or **outbound**, and attachable to three different places: individual **attachments** (via routing-policy labels and `attachment-routing-policy-rules`), **segment shares**, or **CNE-to-CNE (edge-location) pairs**.

| Capability | What it does | Typical use |
|------------|--------------|-------------|
| **Route filtering** | `allow` / `drop` routes by prefix, prefix list, or BGP community | Stop secondary VPC CIDRs (e.g. Kubernetes pod ranges) from propagating; protocol-specific segments |
| **Route summarization** | Replace matched prefixes with one summary route | Shrink the routing table advertised to on-premises routers |
| **Path preferences** | Modify AS_PATH (prepend/replace), local preference, MED | Steer which hybrid edge or Region a prefix is preferred through |
| **BGP communities** | Match on, act on, and transitively pass communities | Carry multiple routing domains over a single BGP session and split them into segments on arrival |

Rules within a policy are numbered and **order matters**: an `allow` for the prefixes you want must have a lower rule number than a catch-all `drop`. The idiomatic "allow-list" shape is `rule 100: allow <what you want>` followed by `rule 200: drop 0.0.0.0/0 + ::/0`.

---

## Constraints that bite

Most Cloud WAN designs go wrong on these specifics rather than on the architecture. Check a design against this list before recommending it.

**Service insertion**

- An attachment is in a segment **or** an NFG, not both.
- **Isolated mode is required** for service insertion between attachments of the same segment.
- **Appliance mode must be enabled** on the inspection VPC, or return traffic will not be symmetric.
- `dual-hop` requires an inspection attachment in **every** Region of the participating segments.
- Static routes in the policy are **not** automatically propagated into NFG route tables.
- With `send-to` enabled you may see `0.0.0.0/0` and `::/0` shown as blackholed in segment routing information. This is expected; check the route tab or `get-network-routes` for the real next hop.
- BGP route updates for NFG route tables can take up to ~30 minutes to appear in `GetNetworkRoutes` and the console, without affecting actual forwarding.

**Routing policies**

- **Not supported for NFGs / service insertion.** You cannot attach a routing policy to an inspection flow. The workaround is to filter at the **attachment** layer *before* traffic enters the inspection path.
- **VPC attachments do not support BGP attribute modification** — no AS_PATH/MED/local-pref games on a VPC attachment. VPC attachments are effectively inbound-filter-only.
- **Summarization is outbound only, and only on BGP-capable attachments** (Site-to-Site VPN, Connect, Direct Connect gateway, TGW peering, CNE-to-CNE).
- **No BGP community support on Direct Connect and TGW peering attachments.**
- Policies applied across segments and Regions are **unidirectional** — declare both directions if you need both.
- ASNs used in a routing policy (replace/remove ASN, community tags) **must not overlap** the core network's own `asn-ranges`.
- **Replace-ASN is not supported cross-Region** (CNE-to-CNE).
- **Segment share policies are applied after attachment policies.**
- **`list-core-network-routing-information` shows routing state BEFORE routing policies are applied.** Do not use it to prove that a filter worked; use `get-network-routes` (or the console route view) for the post-policy state.
- Prefix list aliases must be unique per core-network prefix-list association, and managed prefix lists referenced by routing policies must live in Cloud WAN's home Region, **us-west-2**.

**General**

- Cloud WAN's control plane / home Region is **us-west-2**; the console lives under AWS Network Manager.
- Bandwidth is a property of the **attachment**, not of the CNE, and for VPC attachments it is per Availability Zone. Scale a Region by adding or resizing attachments, not by adding CNEs; aggregate across VPN tunnels or Connect peers with ECMP. Check the [quotas page](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html) for current figures before assuming headroom, and never quote them from memory.
- Cloud WAN does **not** solve overlapping CIDRs. It is IP routing; addresses must be unique. (If overlapping CIDRs are the actual requirement, the answer is VPC Lattice or PrivateLink, not Cloud WAN.)

---

## When to use Cloud WAN

Cloud WAN is the way AWS recommends building networks at AWS: it manages the topology for you — routers, peering mesh, route tables, attachment association — from one declarative, versioned policy, and it scales from a single Region to a global network without re-architecture. The [AWS Networking Best Practices guide](https://aws.github.io/aws-networking-best-practices/connectivity/within-aws/) is the authoritative source for this positioning and for how Cloud WAN combines with Transit Gateway, VPC Lattice, PrivateLink, and VPC peering; ground fit discussions in it.

The recommendation splits on whether the network exists yet:

**Greenfield (new multi-account network): Cloud WAN is the way to go.** Recommend it as the default, whether the customer starts in one Region or many. The policy defines the entire topology declaratively, so they avoid stitching together individual Transit Gateways, peering connections, and route tables as they grow — and avoid the migration those create later. Single-Region is not a reason to hold back: policy-driven management, segmentation, and automated attachment onboarding are the value even before a second Region exists, and adding Regions later is a policy change, not a rebuild.

**Brownfield (existing Transit Gateway network): recommend Cloud WAN only on a real trigger.** A working Transit Gateway setup has no urgency to migrate — say that plainly. Recommend the move when the customer genuinely has a dynamic environment, or growth and expansion ahead of them, concretely:

- Centralized segmentation policies need to apply consistently network-wide, and keeping individual TGW route tables in sync has become error-prone.
- The organization is scaling to dozens or hundreds of accounts and manual route management is slowing teams down.
- They want policy-driven attachment acceptance so the networking team stops being the onboarding bottleneck.
- They run Transit Gateways in multiple Regions and inter-Region routing management has become complex.

When the trigger exists, the path is incremental, not a cutover: peer the existing Transit Gateways to Cloud WAN (a first-class, supported topology), extend TGW route tables into segments, move VPC attachments gradually, and decommission Transit Gateways as they empty.

**The value proposition to articulate**, whichever side of the split applies: the network is defined as code in one reviewable, diffable, rollback-able document; segments make trust boundaries a first-class global concept; attachment policies plus tags let workload teams self-serve onboarding under central governance; service insertion turns inspection changes into policy changes; and routing policies give BGP-level control at the hybrid edge without third-party appliances.

Prefer a different tool when the requirement is not network-level IP connectivity:

- **Overlapping CIDRs, or service-level rather than network-level connectivity** → **Amazon VPC Lattice** (service-to-service, identity-based auth, CIDRs may overlap) or **PrivateLink** (one-way exposure of a single endpoint). Cloud WAN is IP routing and cannot express either.
- **Two VPCs, lowest possible cost and complexity, no growth expected** → **VPC peering**.
- Remember these are **complementary layers, not competing alternatives**: a mature network runs Cloud WAN as the backbone with Lattice, PrivateLink, and targeted peering on top. Do not frame the choice as either/or when the user's requirements span layers.

---

## How to architect with Cloud WAN

A repeatable design workflow:

1. **Establish the segmentation model first.** This is the decision everything else hangs off. Pick the axis (environment, business unit, geography) and enumerate the segments. Resist one-segment-per-application; segments are routing domains, not applications.
2. **Decide per segment whether attachments may talk to each other.** Non-isolated for a normal workload segment; isolated for shared-services or for any segment whose intra-segment traffic must be inspected.
3. **List the Regions** and declare them as `edge-locations`. Reserve an `asn-ranges` block that does not collide with any ASN you use on-premises or in routing policies.
4. **Declare the connectivity you want between segments**, as explicit `share` actions. Remember sharing is non-transitive; draw the graph and declare every edge.
5. **Decide the inspection posture.** Egress inspection → `send-to`. East-west inspection → `send-via`, and choose `dual-hop` (inspect in both Regions, needs inspection everywhere) or `single-hop` (inspect once, define the Region matrix with `with-edge-overrides`). Set the participating segments to isolated where intra-segment traffic must be inspected, and enable appliance mode on the inspection VPCs.
6. **Write the attachment policies** so attachments self-associate. Prefer a tag-driven rule (`association-method: tag`, `tag-value-of-key: <key>`) over a long list of constants, and add explicit rules for hybrid attachment types and for inspection VPCs (`add-to-network-function-group`).
7. **Add routing policies only where a real requirement exists.** They are the sharpest tool here and the easiest to get subtly wrong. Check the design against *Constraints that bite* — especially "not supported for NFGs" and "VPC attachments cannot modify BGP attributes".
8. **Plan the hybrid edge.** Which attachment type (VPN / Direct Connect gateway / Connect), which segment it lands in, what it advertises, and what it should receive. Summarization and community-based filtering both live here.
9. **Deploy as a policy version and read the change set** before executing. Treat the change set as the review artifact.
10. **Validate against the post-policy routing state**, using `get-network-routes` rather than `list-core-network-routing-information`.

---

# How to use this repository

AWS Cloud WAN Blueprints separates two things, and understanding the split is most of what
you need to navigate it:

| Tree | Contains | Organised by |
|------|----------|--------------|
| [`infra/`](./infra/) | **Deployable infrastructure** | Which **attachment types** exist |
| [`policy/`](./policy/) | **What a network policy can express** | The policy document's own top-level arrays |

They are decoupled on purpose. Inspection does not care whether an attachment is a VPC or
a VPN; route filtering does not care whether a prefix came from a VPC or a Transit Gateway.
So an `infra/` pattern does not represent a use case — it provides a set of attachment
types that **any** compatible policy can be pointed at.

The consequence for you: **a use case is a policy, not a directory.** Do not look for a
directory matching the user's requirement. Build the policy, then pick the pattern that
has the attachment types it needs.

## `policy/` — the capability pages

Each page maps to a part of the JSON, so once you know which array you need, you know which
page to read:

| Page | Produces |
|------|----------|
| [`1-core_network_version_configuration.md`](./policy/1-core_network_version_configuration.md) | `core-network-configuration` |
| [`2-segments-and-nfg.md`](./policy/2-segments-and-nfg.md) | `segments` |
| [`3-attachment_policies.md`](./policy/3-attachment_policies.md) | `attachment-policies` |
| [`4-segment_sharing.md`](./policy/4-segment_sharing.md) | `segment-actions` (`share`) |
| [`5-service_insertion.md`](./policy/5-service_insertion.md) | `network-function-groups`, `segment-actions` (`send-to`, `send-via`) |
| [`6-static_routes.md`](./policy/6-static_routes.md) | `segment-actions` (`create-route`) |
| [`7-routing_policies.md`](./policy/7-routing_policies.md) | `routing-policies` |
| [`8-edge_location_associations.md`](./policy/8-edge_location_associations.md) | `segment-actions` (`associate-routing-policy`) |
| [`9-attachment_routing_policy_rules.md`](./policy/9-attachment_routing_policy_rules.md) | `attachment-routing-policy-rules` |

**Snippets, not full policies.** A *snippet* is a fragment — one array element or one
array — illustrative and not deployable alone. Snippets live inline on the pages above and
are the only JSON `policy/` contains: there is no library of ready-made policy documents,
because a real requirement is not drawn from a fixed set, and a library never has the
combination the next user needs. Composing snippets into a full document is this
capability's job, not a file's — that is what the rest of this section walks through.

## The attachment association contract

This is the interface between the two trees. Patterns that create attachments use a common association contract where it fits, so a policy written from `policy/` can bind against any compatible pattern. Some patterns intentionally match by attachment type, and patterns that create no attachments only document the contract an added attachment must follow:

| Tag | Applied to | Purpose |
|-----|------------|---------|
| `domain = <segment>` | VPC and Transit Gateway route-table attachments | Associate to the segment named by the value |
| `inspection = true` | Inspection VPC attachments | Add to the inspection network function group |

Hybrid attachments carry **no tag** — they are matched on `attachment-type`. That asymmetry
is deliberate: use a tag when the destination is a *choice* the attachment owner makes; use
the attachment type when the type *is* the intent.

A policy whose `attachment-policies` do not match these tags produces attachments that
reach `AVAILABLE` and never associate — the quietest failure in Cloud WAN.

## Tooling

| Tool | Does |
|------|------|
| `.github/scripts/check_policies.py` | CI and local pre-commit. Checks that each generated `core_network*.yaml` matches its suffix-paired `baseline*.json` and that every policy document is structurally valid. Not a tool for answering a user's question |

Requires PyYAML (CI pins `6.0.2`) and does not contact AWS.

## Things to tell the user, unprompted

- **Cost.** Every pattern creates billable resources: Core Network Edges bill hourly per
  Region regardless of traffic. `2-inspection` adds AWS Network Firewall and NAT gateways
  and is materially more expensive. Recommend a non-production account and the cleanup
  steps.
- **The two-Region limit.** `single-hop` and `dual-hop` service insertion look almost
  identical with one Region pair. If the design turns on that difference, say that
  observing it needs a third Region.
- **Verification.** `list-core-network-routing-information` shows routing state *before*
  routing policies are applied. Use `get-network-routes` to prove a filter, summarization,
  or path preference took effect.
- **The change-set dry run.** Creating a policy version validates it server-side and
  changes nothing until executed. For anything going near a real network, recommend it.

## Conventions to respect when editing this repository

- An `infra/` pattern is defined **only** by which attachment types it creates. It must not
  encode a use case.
- `baseline.json` is the normal source of truth for a pattern's initial policy. A documented
  staged dependency may add suffix-paired `baseline_<stage>.json` and
  `cloudformation/core_network_<stage>.yaml` documents. Terraform reads the JSON with
  `file()`; CloudFormation embeds the matching document, and CI compares each pair.
- `policy/` contains inline, composable snippets only. If a correctly composed policy reveals
  an undocumented interaction, update the relevant capability page and constraint checklist
  rather than adding a complete example policy.
- [`CONVENTIONS.md`](./CONVENTIONS.md) is the authoritative contract for how the repository
  is laid out and what a contribution must satisfy.

---

# Building a policy

This is the **generator** half of the skill: the workflow for turning a stated requirement
into a **validated** Cloud WAN network policy document, assembled from the snippets in
[`policy/`](./policy/). A human can follow the same steps by hand.

Everything above [How to use this repository](#how-to-use-this-repository) is knowledge —
true regardless of this repository. Everything from there down is procedure, and it
changes when this repository's structure or tooling changes.

## 0. Translating what the user said

Users do not describe networks in Cloud WAN nouns. Map their language first, because the
wrong noun leads to a policy that cannot express the requirement.

| The user says | It means | Where it lands |
|---------------|----------|----------------|
| "environments", "prod and dev", "business units", "regions of the business" | A segmentation axis | `segments` |
| "these two must not talk" | The **absence** of a share. Cloud WAN has no deny action | `segment-actions` — omit it |
| "these two must talk" | An explicit, non-transitive share. Declare every pair | `segment-actions` (`share`) |
| "shared services", "central tooling" | One segment shared with several others, usually isolated | `segments` + `share` |
| "DMZ", "inspect between environments" | An isolated segment plus a network function group | `segments` (`isolate-attachments`) + `send-via` |
| "all internet traffic must be inspected" | Egress inspection | `send-to` |
| "teams onboard their own VPCs" | Tag-driven association | `attachment-policies` (`association-method: tag`) |
| "the network team must approve" | Attachment acceptance | `segments` (`require-attachment-acceptance`) |
| "don't advertise our pod CIDRs" | Inbound route filtering at the attachment | `routing-policies` |
| "on-prem only needs a summary" | Outbound summarization on a BGP-capable attachment | `routing-policies` |
| "prefer the London circuit" | Path preference | `routing-policies` |
| "we already run Transit Gateway" | A `transit-gateway-route-table` attachment, not a migration blocker | attachment type |

Two translations to get right because the user's phrasing actively misleads:

- **"Block" is not an action.** Segments are unreachable by default; a "block" requirement is satisfied by not declaring a share. If a user insists on an explicit deny, explain that the model is deny-by-default and the policy expresses only what is permitted.
- **"Isolate" is ambiguous.** Between segments, isolation is the default. Within a segment, it is `isolate-attachments: true`. Ask which they mean, because the second one is also a prerequisite for inspecting intra-segment traffic.

## 1. Intake

Answer these before writing any JSON. Most bad Cloud WAN policies come from a skipped
question here rather than from a syntax error.

**Ask in standard networking terms.** The user should not need Cloud WAN vocabulary to
answer. Ask about routing domains, reachability, inspection, and route advertisement, then
translate the answers into Cloud WAN constructs yourself using
[step 0](#0-translating-what-the-user-said). The Cloud WAN mapping in parentheses after
each question below is for you, not for the user.

**Not every question carries the same weight.** Each is tagged with a tier that decides
what happens when it goes unanswered:

- **[Crucial]** — the policy would be structurally wrong on a guess. Ask, offer concrete
  options, and push back before proceeding. Generate anyway only if the user explicitly
  says to, and mark every affected section with a red flag.
- **[Important]** — a conservative default exists. Ask once; if unanswered, proceed on the
  default and mark the affected section with a yellow flag.
- **[Good to have]** — a safe default exists. Do not press; apply the default and mark it
  green.

**The flag report.** Whenever a default or a substitute stands in for an answer, the
hand-back must carry a colour-coded report naming the affected policy section — so the
user knows exactly where to look to bring the document closer to their use case:

| Flag | Means | The user should |
|------|-------|-----------------|
| 🔴 Red | A crucial input was missing; the section is built on a substitute | Review the section before doing anything else with the policy |
| 🟡 Yellow | An important input was assumed | Confirm or correct the assumption |
| 🟢 Green | A good-to-have default was applied | Review when convenient; the default is safe |

Flag **sections**, not the document: name the policy part next to each flag (`segments`,
`segment-actions`, `attachment-policies`, `core-network-configuration`, ...).

**Regions**

- [Crucial] Which AWS Regions does the network operate in? Each Region added to the policy
  deploys a router that bills hourly whether or not it carries traffic, so do not list
  Regions speculatively. (`edge-locations`.)
- [Good to have] Is expansion into more Regions likely? Adding one later is a policy
  change, not a rebuild. Default: size the ASN ranges generously, which costs nothing.
  (`asn-ranges`.)

**Addressing**

- [Crucial] Do any of the networks being connected have overlapping IP ranges — or might
  they in the future? Cloud WAN is IP routing and addresses must be unique. If overlap is
  fundamental to the requirement, stop: the answer is VPC Lattice or PrivateLink, not a
  Cloud WAN policy.
- [Important] IPv4-only or dual-stack? Default: recommend configuring IPv6 alongside IPv4
  from the start — retrofitting it into a live policy is far more disruptive than
  including it now.
- [Important] Which BGP ASNs are already in use on-premises or in the SD-WAN? This only
  rises to important when something BGP-capable connects; the core network's ranges and
  any routing-policy ASNs must not collide with them. (`asn-ranges`.)

**Routing domains**

- [Crucial — with derivation logic] What are the network's routing domains, and what is
  the axis — environment, business unit, geography? (`segments`.)

  This is the one crucial question you may answer *for* the user, because segmentation has
  design logic you can apply. If they cannot enumerate their domains, derive a proposal
  and red-flag `segments`:

  1. Segments are **trust boundaries and routing domains**, not a mirror of environment
     names. Start from what must never mix: compliance scopes (a `pci` segment may span
     production and staging), data classifications, tenants.
  2. Anything consumed by many domains — DNS, identity, monitoring, tooling — belongs in
     a **shared-services** segment, shared explicitly with its consumers and usually
     isolated.
  3. If on-premises connectivity exists, consider a **hybrid** segment grouping the VPN
     and Direct Connect attachments, so inspection and route control toward on-premises
     apply in one place.
  4. If nothing else is known, the **environment axis** (production / development) is the
     simplest defensible starting point: two segments, no sharing, expand later.
  5. Keep the count small. One segment per application is an anti-pattern — segments are
     routing domains, not applications.

- [Crucial] Which routing domains must reach each other? Unconnected is the default, so
  collect the pairs that *must* communicate rather than the ones that must not. Do not
  guess this one: an assumed connection is a security decision taken without the user.
  (`share` actions.)
- [Important] Within a routing domain, may members reach each other directly? Default:
  yes, open within the domain. **Escalates to crucial** when east-west inspection is in
  scope, because isolation is what forces intra-domain traffic through the firewall.
  (`isolate-attachments`.)

**What connects, and who owns it**

- [Crucial] What connects to the network: VPCs, on-premises sites over IPsec VPN or
  dedicated circuits, SD-WAN appliances, existing Transit Gateways? (Each maps to an
  attachment type, and decides which pattern can host the policy.)
- [Important] Are connections created by teams or accounts other than the network owner?
  Default: same-owner. Tag-based association delegates routing-domain choice across a
  trust boundary — see [`3-attachment_policies.md`](./policy/3-attachment_policies.md).
- [Good to have] Are any routing domains sensitive enough that joining them should require
  the network team's explicit approval? Default: no approval gate.
  (`require-attachment-acceptance`.)

**Inspection**

- [Crucial] Must traffic pass through a firewall — internet-bound (north-south), between
  workloads (east-west), or both? (`send-to`, `send-via`.)
- [Important] For east-west: must traffic be inspected in every Region it touches, or is
  one inspection point per path acceptable? Compliance requirements usually decide this,
  not cost — if unanswered, state the assumption and say exactly that. (`dual-hop` versus
  `single-hop`.)
- Derived, not asked: a Region with no local firewall needs an edge override. Compute this
  from the Regions and inspection answers.

**Route control**

[Good to have] Most networks need none of this, so open with a single question: **"Do you
need any additional routing controls?"** Default: none. If the answer is yes — or the user
asks what that means — expand in plain networking terms:

- Are there prefixes that should stay hidden from the rest of the network — secondary
  CIDRs, container or pod ranges, lab networks? (Route filtering.)
- Should on-premises routers receive a few summary routes instead of every VPC prefix?
  (Route summarization.)
- Are there multiple paths to the same destination that need an explicit preference —
  active/backup circuits, geographically aligned exits? (Path preference via BGP
  attributes.)
- Does a single BGP session carry routes for several routing domains that must be split
  apart on arrival? (BGP community matching.)

**How it will be deployed**

- [Important] **Which IaC tool — Terraform or CloudFormation?** It does not change a
  single line of the policy, but it changes what you hand back, because the two tools
  consume a policy differently: Terraform reads a JSON file at plan time, while
  CloudFormation needs the policy inline in the template. This question never blocks
  design — it must be answered by [hand-back](#6-what-to-hand-back) time; if it never is,
  deliver JSON and say why.

**Ambiguity**

The tiers above decide how each gap is handled, and the flag report is where every gap
lands. One addition: the core configuration carries defaults the user never chose — DNS
support, security-group referencing, ECMP — list them green-flagged against
`core-network-configuration` so they are conscious choices rather than silent ones.

## 2. Assembly order

Build the document in the order of the pages in [`policy/`](./policy/). It is not
arbitrary — each part references the ones before it, so building out of order means rework.

| Step | Page | Produces | Depends on |
|------|------|----------|-----------|
| 1 | [`1-core_network_version_configuration.md`](./policy/1-core_network_version_configuration.md) | `core-network-configuration` | — |
| 2 | [`2-segments-and-nfg.md`](./policy/2-segments-and-nfg.md) | `segments` | Edge locations |
| 3 | [`3-attachment_policies.md`](./policy/3-attachment_policies.md) | `attachment-policies` | Segments, and the network function group if inspecting |
| 4 | [`4-segment_sharing.md`](./policy/4-segment_sharing.md) | `segment-actions` (`share`) | Segments |
| 5 | [`5-service_insertion.md`](./policy/5-service_insertion.md) | `network-function-groups`, `segment-actions` (`send-to`, `send-via`) | Segments, and isolation set correctly in step 2 |
| 6 | [`6-static_routes.md`](./policy/6-static_routes.md) | `segment-actions` (`create-route`) | Segments, and the attachments a route points at |
| 7 | [`7-routing_policies.md`](./policy/7-routing_policies.md) | `routing-policies` | Everything above |
| 8 | [`8-edge_location_associations.md`](./policy/8-edge_location_associations.md) | `segment-actions` (`associate-routing-policy`) | The routing policies from step 7 |
| 9 | [`9-attachment_routing_policy_rules.md`](./policy/9-attachment_routing_policy_rules.md) | `attachment-routing-policy-rules` | The routing policies from step 7 |

Two ordering traps worth naming:

- **Isolation is decided in step 2 but required by step 5.** If you add `send-via` for
  intra-segment traffic later, go back and set `isolate-attachments: true`. Forgetting this
  produces a policy that deploys and silently bypasses the firewall.
- **The network function group is declared in step 5 but referenced in step 3.** The
  attachment policy that puts inspection VPCs into the group needs a *low* rule number, or
  a later `tag-exists: domain` rule claims them first.

## 3. Constraint checklist

Check the draft against these before you deploy it. The facts behind them are in
[Constraints that bite](#constraints-that-bite); what this list adds is the order to check
them in. Most are AWS-documented Cloud WAN limitations rather than style preferences — the
[routing policies key considerations](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html)
and [service insertion considerations](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-service-insertion.html)
pages are the source, and worth reading in full.

**Will it be accepted?**

- [ ] Every segment referenced by a segment action or attachment policy is declared
- [ ] Every network function group referenced is declared
- [ ] Every Region in `with-edge-overrides` is a declared edge location
- [ ] Every routing policy name referenced is declared
- [ ] Rule numbers are unique within each numbered array
- [ ] ASNs used by a routing policy do not overlap the core network's `asn-ranges` — [and
      you cannot advertise communities containing an ASN the core network is using](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html)

**Will it do what you meant?** These are the ones that get accepted and then silently
misbehave, which is why they are worth a second pass.

- [ ] `allow` rules have a **lower** rule number than any catch-all `drop`, or they can
      never match
- [ ] Segments carrying intra-segment `send-via` inspection are **isolated** — [isolated
      mode is required for service insertion between attachments in the same
      segment](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-service-insertion.html), and without it traffic takes the direct route and bypasses
      the firewall with no error anywhere
- [ ] `dual-hop` is only used where an inspection attachment exists in every participating
      Region
- [ ] No routing policy is attached to a network function group — [routing policies are not
      supported for NFGs](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html), so filter at the attachment layer instead
- [ ] `summarize` actions are `outbound` and target BGP-capable attachments — [summarization
      works outbound only](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html)
- [ ] BGP communities are not expected on Direct Connect or Transit Gateway peering
      attachments, which [do not support them](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html)
- [ ] No BGP attribute modification is aimed at a VPC attachment — [VPC attachments do not
      support it](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html)
- [ ] Prefix lists referenced by a routing policy are [created in the Cloud WAN home Region,
      `us-west-2`](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-prefix-lists.html), wherever the edge locations are, **and associated with the
      core network before the policy that names the alias is applied**
- [ ] Every tag the target infrastructure applies is matched by an attachment policy, and the
      `edge-locations` match the Regions it deploys into. Get either wrong and attachments
      reach `AVAILABLE` and never associate — the most common way a valid policy moves no
      traffic

**Did you check the right thing afterwards?**

- [ ] Verification uses `get-network-routes`, **not**
      `list-core-network-routing-information` — [the latter shows routing information before
      routing policies have been applied](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html)

## 4. Validate

Cloud WAN validates a policy when you create a **policy version**, and produces a **change
set** you must explicitly execute. Nothing changes until you do, which makes this a genuine
dry run and the authoritative check — it knows the current state of the network, which no
offline tool does.

```bash
aws networkmanager put-core-network-policy \
  --core-network-id <id> \
  --policy-document file://my-policy.json
```

**This step belongs to the user — hand it over as an explicit recommendation, not a
footnote.** Give them the exact command, tell them to review the change set Cloud WAN
generates before executing it, and to send back the validation error if the policy is
rejected. Say plainly that your offline checks are not a substitute for this step. Two
things they should know before running it:

- The command needs an existing core network (`--core-network-id`). On an existing
  **non-production** core network, creating a policy version is safe: nothing changes
  until the change set is executed.
- If no core network exists yet, testing means creating a global network and a core
  network with this policy as its first version — which deploys Core Network Edges that
  bill hourly. Recommend a non-production account and cleanup when finished; the
  [`infra/`](./infra/) pattern recommended in [step 5](#5-choosing-infrastructure) is the
  packaged way to do exactly that.

Review the change set, then execute it — for anything destined for a real network this
step is not optional.

If the policy is rejected, the error names the offending part of the document. Work back from
it to the checklist above rather than guessing.

## 5. Choosing infrastructure

A policy needs somewhere to run. Recommend the pattern that creates the attachment types the
policy expects — nothing more:

| If the policy needs | Deploy |
|---------------------|--------|
| VPC attachments only | [`1-basic`](./infra/1-basic/) |
| A network function group (any inspection) | [`2-inspection`](./infra/2-inspection/) |
| Transit Gateway route-table attachments | [`3-transit_gateway`](./infra/3-transit_gateway/) |
| Any BGP capability, or hybrid attachments | [`4-hybrid`](./infra/4-hybrid/) |
| A core network shared across accounts | [`5-multi_account`](./infra/5-multi_account/) |
| A prefix list associated with the core network | [`6-prefix_list_association`](./infra/6-prefix_list_association/) |

Every pattern's baseline policy declares **two Core Network Edge locations** (`us-east-1`,
`eu-west-1`) and forwards traffic before the user writes anything. The managed resources do
not always live in both edge Regions; `infra/README.md` documents each pattern's actual
resource locations. Point a pattern at a different policy with one variable:

```bash
cd infra/2-inspection/terraform
terraform apply -var policy_document=../../../my-policy.json
```

**Frame the recommendation as a PoC deployment**: a non-production account, the pattern's
*Cost* section read first, and its cleanup steps run when finished. The pattern exists to
exercise the policy and prove the design, not to be the production network.

The patterns are building blocks, not finished answers — a policy that needs more than a
pattern ships with is normal, not a mismatch. When that happens, recommend the **closest**
pattern, state explicitly what it lacks, and describe the adaptation. Distinguish the two
kinds:

- **Changes the pattern already parameterizes.** More or different spoke VPCs and CIDRs
  are variable edits, not code changes: the per-Region maps in Terraform
  (`<region>_spoke_vpcs` and friends in `variables.tf`) or the `Mappings` blocks in
  CloudFormation. Different or additional Regions follow the file-by-file steps in
  [`infra/README.md`](./infra/README.md)'s *Regions* section. Different tags mean keeping
  both halves of the association contract aligned — see *How attachments are associated*
  there. For these, name the exact variable or mapping to edit.
- **Structural changes the pattern does not parameterize.** A second inspection VPC per
  Region, a piece borrowed from another pattern, extra workload resources. These are
  legitimate too: duplicate the relevant Terraform module block or CloudFormation resource
  set, keep the association contract intact (the new attachment must carry a tag or
  attachment type the policy matches, or it will sit `AVAILABLE` and unassociated), and
  list exactly which files you changed and why in the hand-back.

Never recommend a pattern as-is when it cannot exercise the policy — say what is missing.
A silently mismatched pattern deploys attachments that reach `AVAILABLE` and never
associate, which the user reads as a broken policy.

## 6. What to hand back

A policy document is not a complete answer on its own. Deliver all five:

**1. The policy document**, validated, with the checks that were run stated — in the form
the chosen tool actually consumes.

**If Terraform**, a JSON file is enough. Terraform reads it at plan time:

```bash
terraform apply -var policy_document=../../../my-policy.json
```

**If CloudFormation**, hand back **both** the JSON *and* the same policy as YAML, ready to
paste under `PolicyDocument:`. This is not a convenience — CloudFormation cannot take the
policy any other way. [`PolicyDocument` on
`AWS::NetworkManager::CoreNetwork`](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-networkmanager-corenetwork.html)
is inline JSON with no S3 or file option, and a [stack parameter caps at 4,096
bytes](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cloudformation-limits.html),
which a real policy exceeds. Leaving the user to convert it themselves is handing them the
error-prone half of the job.

Four conversion rules, because YAML will silently change a value's *type* where JSON could
not:

| Value | JSON | YAML | Why |
|-------|------|------|-----|
| Policy version | `"2025.11"` | `version: "2025.11"` | Unquoted it becomes the float `2025.11` and the policy is rejected |
| A tag **value** that reads as a boolean | `"value": "true"` | `value: "true"` | Unquoted it becomes the boolean `true`, the condition stops matching the string tag, and **attachments silently never associate** |
| A real boolean | `"isolate-attachments": true` | `isolate-attachments: true` | Genuinely a boolean — do **not** quote it |
| `share-with` wildcard | `"share-with": "*"` | `share-with: "*"` | A bare `*` is a YAML alias indicator |

The second row is the one that bites. In JSON the difference between `"true"` and `true` is
visible; in YAML dropping the quotes produces a document that is valid, deploys cleanly, and
does nothing.

ASN ranges (`64520-64525`), CIDRs (`10.0.0.0/8`), and BGP communities (`65051:200`) need no
quoting in block style, but quoting them is never wrong.

**2. Which pattern to deploy, and why** — from [Choosing infrastructure](#5-choosing-infrastructure).

**3. The residual manual steps a policy cannot express.** These are the usual reason a
correct policy still does not work:

- **Appliance mode** on the inspection VPC attachment, or return traffic is asymmetric and
  flows drop.
- **Managed prefix lists created in `us-west-2`** and associated with the core network,
  for any summarization policy — and the association has to exist *before* the policy that
  references its alias.
- **Routing-policy labels** applied to the attachments the `attachment-routing-policy-rules`
  target.
- **On-premises BGP configuration** — which prefixes are advertised, which communities are
  set, which ASNs are used.
- **Direct Connect circuits and virtual interfaces**, which cannot be simulated.

**4. The flag report.** Every default or substitute that stands in for an unanswered
intake question, colour-coded as defined in [Intake](#1-intake) — 🔴 crucial inputs that
were missing, 🟡 important ones assumed, 🟢 good-to-have defaults applied — each naming the
policy section to review. A flag with a section name is actionable; a prose paragraph of
assumptions is not.

**5. What cannot be observed in this environment.** Most commonly: with a two-Region
deployment, `single-hop` and `dual-hop` behave almost identically because there is one
Region pair. Say so rather than letting someone conclude the policy is wrong.

Finally, tell the user how to report a miss: if the generated policy does not match the
requirements they gave, they should file it with the repository's [unexpected policy output
issue template](https://github.com/aws-samples/aws-cloud-wan-blueprints/issues/new?template=unexpected_policy_output.md),
including the prompt, the generated policy, and what they expected — that is how this skill
improves.

## 7. Troubleshooting and extending an existing policy

Users will also bring you a policy they already have, in one of two shapes: **"why is this
not working?"** and **"how can this policy also do X?"**. Both start the same way: read the
document they sent before answering anything, and ask for the intent in their own words —
you cannot diagnose or extend a policy against an intent you are guessing at.

### "Why is this not working?"

This is a **static review**. You work from the policy document, the user's statement of
intent, whatever evidence they share, and this repository's knowledge base plus the AWS
documentation — nothing else. Do not make AWS API calls: every command mentioned below is
something you ask the user to run and paste back.

Review the document against two different questions, in order:

1. **Is the policy internally correct?** Run both halves of the
   [constraint checklist](#3-constraint-checklist). The *will it be accepted* half catches
   rejections; the *will it do what you meant* half catches the more common case — the
   policy that deploys cleanly and silently does something else.
2. **Does the policy express the stated use case?** Reconstruct from the document alone
   what the network actually does — which routing domains exist, which pairs communicate,
   what traffic is inspected and where, which routes are filtered, summarized, or
   preferred — and lay that reconstruction next to what the user says they want. The
   difference between the two is the diagnosis. A policy can pass every constraint check
   and still be a correct implementation of the wrong intent.

Separate what the document can prove from what it cannot. Rule ordering, a missing
`share`, missing isolation, a filter aimed at a network function group — those are visible
in the JSON, and you can point at the exact section. Whether appliance mode is enabled,
which tags the attachments actually carry, whether the prefix list was associated — those
live in the environment, and the review can only turn them into precise questions for the
user. Where evidence would decide between hypotheses, ask for it, in this order of
likelihood:

1. **Was the policy version rejected?** Ask for the error — it names the offending part.
   Work back from it through the checklist; dangling references and rule-number collisions
   account for most rejections.
2. **Do attachments sit `AVAILABLE` and unassociated?** Ask which tags the attachments
   actually carry and compare them against what the `attachment-policies` match — and the
   policy's `edge-locations` against the Regions the attachments deploy into. This is the
   quietest and most common failure.
3. **Associated, but no reachability?** Deny-by-default first: a missing `share` is the
   design working as intended — confirm the two domains were ever meant to communicate
   before treating it as a bug. Then isolation (`isolate-attachments` blocks intra-segment
   traffic), then the inspection path: ask whether appliance mode is enabled on the
   inspection VPC, and whether an inspection attachment exists in every Region `dual-hop`
   requires.
4. **Reachable, but the wrong path or routes?** Routing-policy territory: `allow` rules
   numbered above a catch-all `drop`, a policy applied in one direction when both were
   needed, a filter aimed at a network function group (unsupported). Ask the user to run
   `get-network-routes` and share the output — not
   `list-core-network-routing-information`, which shows pre-policy state — and note that
   BGP updates for NFG route tables can lag the console by up to ~30 minutes without
   affecting actual forwarding.

Report the finding in standard networking terms, name the policy section it lives in, and
propose the fix as a **minimal diff** — then recommend re-validating through the
change-set workflow in [step 4](#4-validate), which the user runs.

### "How can this policy also do X?"

Treat it as a delta through the same pipeline, not a rewrite:

1. [Translate](#0-translating-what-the-user-said) X, and run only the parts of
   [intake](#1-intake) the new capability needs — the tiers and the flag report apply to
   the delta exactly as they do to a full generation.
2. Read the existing document's conventions first — naming, rule numbering, association
   method — and follow them. The user owns this document; your change should look like it
   belongs there.
3. Check the delta's **interactions** with what already exists, not just the delta itself:
   a new `share` against the segments' isolation expectations, a new `send-via` against
   segments that are not isolated, new rule numbers against the ones in use.
4. Hand back a **minimal diff** with the affected sections named, the flag report for
   anything assumed, and the recommendation to validate through [step 4](#4-validate).

If X is not expressible in a network policy — overlapping CIDRs, service-level access
control, a routing policy on an inspection flow — say so plainly and point at what can
express it, rather than bending the policy toward something it cannot do.

## Worked example

> *"Two Regions. Production and development must not talk to each other. All
> internet-bound traffic must be inspected, and so must anything entering or leaving
> production. Our Kubernetes pod CIDRs must not leak into the wider network."*

**Translate.** "Must not talk" is the absence of a share, not a deny rule. "Anything
entering or leaving production" includes production-to-production, so `production` has to
be isolated. "Must not leak" is inbound route filtering at the VPC attachment.

**Intake.** Two Regions. Segments `production`, `development`. No sharing between them.
Egress inspection for both. East-west inspection for `production`. Pod CIDRs are a
filtering requirement at the VPC attachment layer, and VPC attachments only support
`inbound`.

**Assembly.** Steps 1–3 give the two Regions, the two segments with `production` isolated,
the network function group, and attachment policies (inspection tag first, then the
`domain` tag). Step 4 adds nothing — no sharing is wanted. Step 5 adds `send-to` for both
segments and `send-via` `dual-hop` for `production`. Step 6 adds an inbound allow-list at
the VPC attachments.

**Constraint check.** The filter cannot attach to the network function group, so it goes at
the attachment layer — which is also where it has to be, since the pod CIDRs should never
enter the segment. `production` is isolated, satisfying the service-insertion prerequisite.
`dual-hop` needs inspection in both Regions.

**Result.** A policy document combining `segments` (`production` isolated,
`require-attachment-acceptance` off), `attachment-policies` (inspection tag first, then
`domain`), `network-function-groups`, `segment-actions` for `send-to` on both segments and
`send-via` `dual-hop` on `production`, and `attachment-routing-policy-rules` filtering the
pod CIDRs inbound before they reach the segment. Assemble it from
[`2-segments-and-nfg.md`](./policy/2-segments-and-nfg.md),
[`3-attachment_policies.md`](./policy/3-attachment_policies.md),
[`5-service_insertion.md`](./policy/5-service_insertion.md) and
[`9-attachment_routing_policy_rules.md`](./policy/9-attachment_routing_policy_rules.md) in
that order, deploy against [`2-inspection`](./infra/2-inspection/), and validate with the
change-set workflow in [`policy/README.md`](./policy/README.md#validating-a-policy).

**Hand back.** The policy, the pattern to deploy against, appliance mode as a
prerequisite, the label `vpcAttachments` to apply to the spoke attachments, the note that
with two Regions `dual-hop` is not visibly different from `single-hop`, and the flag
report — here 🟡 `segments` (intra-development reachability was never stated; assumed
open) and 🟢 `core-network-configuration` (DNS support, security-group referencing, and
ECMP left at defaults).

---

## Quick-reference facts

| Fact | Value |
|------|-------|
| Control plane / home Region | `us-west-2` |
| Console | AWS Network Manager |
| Policy format | declarative JSON, versioned, change-set gated |
| Policy version used by this repository's patterns | `2025.11` |
| Regional router | Core Network Edge (CNE), one per `edge-location` |
| Inter-CNE routing | automatic full mesh, e-BGP |
| Throughput | a property of the **attachment**, not the CNE; per Availability Zone for VPC attachments |
| Segment scope | global (one route table across all CNE Regions) |
| Attachments per segment | an attachment belongs to exactly one segment **or** one NFG |
| Attachment types | VPC, Site-to-Site VPN, Direct Connect gateway, Transit Gateway route table, Connect |
| Segment-to-segment | `share` action, **non-transitive** |
| Deny action | **none** — segments are unreachable unless shared |
| East-west inspection | `send-via` (+ `dual-hop` / `single-hop`) |
| Egress inspection | `send-to` |
| Inspection container | network function group (NFG), a global construct |
| BGP-capable attachments | Site-to-Site VPN, Connect, Direct Connect gateway, TGW peering, CNE-to-CNE |
| Routing policy directions | `inbound`, `outbound` |
| Routing policies on NFGs | **not supported** |
| Overlapping CIDRs | **not supported** (use VPC Lattice / PrivateLink instead) |
| Prefix lists for routing policies | must be created in `us-west-2`, and associated before the policy references the alias |

## Authoritative references

- What is Cloud WAN: https://docs.aws.amazon.com/network-manager/latest/cloudwan/what-is-cloudwan.html
- AWS Networking Best Practices — connectivity within AWS (positioning, when to use, migration from TGW, combining services): https://aws.github.io/aws-networking-best-practices/connectivity/within-aws/
- Core network policies and change sets: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-change-sets.html
- Policy versions and deployment: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-create-policy-version.html
- Service insertion (incl. considerations): https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-service-insertion.html
- Routing policies (incl. key considerations): https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html
- Create a routing policy and rule: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-route-policy.html
- Routing policy example policy document: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-examples-routing-policies.html
- Prefix list associations: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-prefix-lists.html
- Attachments: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-attachments.html
- Quotas: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html
- Cloud WAN FAQs: https://aws.amazon.com/cloud-wan/faqs/
- This repo — policy guidance: [`policy/`](./policy/) · infrastructure: [`infra/`](./infra/)
- This repo — contract: [`CONVENTIONS.md`](./CONVENTIONS.md) · [`README.md`](./README.md)
