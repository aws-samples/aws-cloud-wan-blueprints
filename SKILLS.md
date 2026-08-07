# AWS Cloud WAN Skill

> **Purpose.** This file is written for an **AI agent**, not (primarily) for a human. Drop it into your agent's context (as a system/skill file, a retrieved document, or pasted reference) so the agent can reason correctly about **AWS Cloud WAN**: what it is, how its policy model works, when it is the right tool, and how to design with it. The human-facing overview lives in [`README.md`](./README.md); the machine-readable pattern catalog lives in [`blueprint.yaml`](./blueprint.yaml).
>
> **Structure.** Part one is *service knowledge* — what Cloud WAN is and how to reason about it. Part two, [How to use this repository](#how-to-use-this-repository), is *repository knowledge* — where the deployable infrastructure and the policy guidance live, and how to turn a requirement into a validated policy. Both are stable enough to lift into an agent's context. [`blueprint.yaml`](./blueprint.yaml) is the machine-readable source of truth for what exists.

## How to use this skill

When a user asks about connecting multiple VPCs and Regions, building a global network, multi-Region segmentation, centralized traffic inspection, migrating from Transit Gateway, or hybrid connectivity at scale:

1. **Ground your mental model** in *What Cloud WAN is* and *The policy model* below. Almost every Cloud WAN question is really a question about the policy document.
2. **Check fit** using *When to use Cloud WAN* before recommending it. It is not always the right tool, and a single-Region, few-VPC design usually should not use it.
3. **Design** with *How to architect with Cloud WAN*, then sanity-check against *Constraints that bite*. That section exists because most Cloud WAN designs fail on a small number of specific, documented limitations rather than on the big picture.
4. **Express the design as a policy document.** The deliverable for a Cloud WAN design is a JSON network policy plus the attachments it expects. Be explicit about segments, segment actions, attachment policies, and (if used) network function groups and routing policies.
5. **Never invent policy syntax.** If you are unsure whether a field, action, or match condition exists, say so and point at the [policy reference](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-change-sets.html) rather than guessing. Cloud WAN validates policy server-side and a wrong field is a hard failure, not a warning.
6. **Use this repository to do the work.** [How to use this repository](#how-to-use-this-repository) below explains where the deployable infrastructure and the policy guidance live. The step-by-step authoring workflow — intake questions, assembly order, constraint checklist, what to hand back — is [`policy/policy_generator.md`](./policy/policy_generator.md). Follow it rather than improvising an order; each part of the document depends on the ones before it.
7. **Validate before you claim it works.** `python3 tools/validate_policy.py <policy> --infra <pattern>` catches the failure modes that deploy cleanly and do nothing. Never present a generated policy as correct without running it.

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
- Each CNE supports up to **100 Gbps**. Check the [quotas page](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html) before assuming headroom.
- Cloud WAN does **not** solve overlapping CIDRs. It is IP routing; addresses must be unique. (If overlapping CIDRs are the actual requirement, the answer is VPC Lattice or PrivateLink, not Cloud WAN.)

---

## When to use Cloud WAN

Recommend Cloud WAN when **most** of these are true:

- The network spans **multiple AWS Regions**, or credibly will.
- You want **segmentation** (environments, business units, geographies) as a first-class, global concept rather than per-Region route tables you keep in sync by hand.
- You want **centralized, policy-driven** network configuration with versioning, review, and rollback — especially across many accounts.
- You want **automatic** cross-Region routing instead of building and maintaining a TGW peering mesh with static routes.
- You need **centralized inspection** of east-west and/or egress traffic, possibly cross-Region.
- You want workload teams to **self-serve** attachments via tags, governed by central policy.
- You need **fine-grained BGP control** at the hybrid edge (filtering, summarization, path preference).

Prefer a different tool when:

- **Single Region, a handful of VPCs** → **Transit Gateway**, or even VPC peering. Cloud WAN's value is global scope and policy governance; neither pays off here.
- **Overlapping CIDRs, or you want service-level rather than network-level connectivity** → **Amazon VPC Lattice** (service-to-service, identity-based auth, link-local addressing, CIDRs may overlap) or **PrivateLink** (one-way exposure of a single endpoint).
- **Two VPCs, lowest possible cost and complexity** → **VPC peering**.
- **You need a specific TGW feature Cloud WAN does not expose**, or your organization has deep existing TGW automation → keep TGW, and consider **peering TGWs to Cloud WAN** so you can migrate incrementally. This is a first-class, supported topology, not a hack.

Rule of thumb: **Transit Gateway for regional connectivity you assemble yourself; Cloud WAN for a global, segmented network you declare. VPC Lattice when the requirement is service access, not IP reachability.**

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

---

# How to use this repository

AWS Cloud WAN Blueprints separates two things that v1 of this repository conflated, and
understanding the split is most of what you need to navigate it:

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

## Answering "how do I do X with Cloud WAN"

1. **Ground the design** in part one above, then in the relevant `policy/` page.
2. **Follow the workflow** in [`policy/policy_generator.md`](./policy/policy_generator.md).
   It has the intake questions, the assembly order, the constraint checklist, and what to
   hand back. Do not improvise a different order — each part of the document depends on the
   ones before it.
3. **Validate** with `tools/validate_policy.py`. Errors must be fixed; warnings name
   constraints the policy alone cannot prove.
4. **Name the infra pattern** to deploy for an end-to-end test, and the residual manual
   steps a policy cannot express.

## `policy/` — the capability pages

Each page maps to a part of the JSON, so once you know which array you need, you know which
page to read:

| Page | Produces |
|------|----------|
| [`1-core_network_configuration.md`](./policy/1-core_network_configuration.md) | `core-network-configuration` |
| [`2-segments.md`](./policy/2-segments.md) | `segments` |
| [`3-attachment_policies.md`](./policy/3-attachment_policies.md) | `attachment-policies` |
| [`4-segment_sharing.md`](./policy/4-segment_sharing.md) | `segment-actions` (`share`) |
| [`5-service_insertion.md`](./policy/5-service_insertion.md) | `network-function-groups`, `segment-actions` (`send-to`, `send-via`) |
| [`6-routing_policies.md`](./policy/6-routing_policies.md) | `routing-policies`, `attachment-routing-policy-rules` |

**Snippets versus examples.** A *snippet* is a fragment — one array element or one array —
illustrative and not deployable alone. Snippets live inline in the pages above and are the
primary content. An *example* is a complete, deployable policy document in
[`policy/examples/`](./policy/examples/), and they are deliberately rare: one exists,
because it demonstrates an interaction that composing snippets by hand gets wrong. Do not
expect an example per use case, and do not treat the absence of one as a gap —
[`policy/README.md`](./policy/README.md) lists the candidates that were rejected and why.

## `infra/` — choosing a pattern

| Pattern | Attachment types | Reach for it when |
|---------|------------------|-------------------|
| [`1-basic`](./infra/1-basic/) | `vpc` | Segmentation, sharing, or inbound route filtering between VPCs |
| [`2-inspection`](./infra/2-inspection/) | `vpc` + inspection VPCs in a network function group | Anything involving service insertion |
| [`3-transit_gateway`](./infra/3-transit_gateway/) | `vpc`, `transit-gateway-route-table` | Transit Gateway coexistence or migration; also the cheapest BGP-capable attachment |
| [`4-hybrid`](./infra/4-hybrid/) | `vpc`, `site-to-site-vpn`, `connect`, `direct-connect-gateway` | Summarization, path preferences, BGP communities, on-premises integration |
| [`5-multi_account`](./infra/5-multi_account/) | none — it shares a core network | Cross-account attachment governance |

Every pattern deploys **two Regions** (`us-east-1`, `eu-west-1`) and ships a **working
baseline policy**, so it deploys and forwards traffic before the user writes anything.
Point a pattern at a different policy with one variable:

```bash
cd infra/2-inspection/terraform
terraform apply -var policy_document=../../../my-policy.json
```

## The attachment tagging contract

This is the interface between the two trees. Every pattern applies the **same** tags, so a
policy written from `policy/` binds against any pattern that has the attachment types it
needs:

| Tag | Applied to | Purpose |
|-----|------------|---------|
| `domain = <segment>` | VPC and Transit Gateway route-table attachments | Associate to the segment named by the value |
| `inspection = true` | Inspection VPC attachments | Add to the inspection network function group |

Hybrid attachments carry **no tag** — they are matched on `attachment-type`. That asymmetry
is deliberate: use a tag when the destination is a *choice* the attachment owner makes; use
the attachment type when the type *is* the intent.

A policy whose `attachment-policies` do not match these tags produces attachments that
reach `AVAILABLE` and never associate — the quietest failure in Cloud WAN. Always run the
contract check:

```bash
python3 tools/validate_policy.py my-policy.json --infra infra/1-basic
```

## Tooling

| Tool | Does |
|------|------|
| `tools/validate_policy.py` | Structure, cross-references, and 14 Cloud WAN constraint checks. `--infra` adds the tagging-contract and Region checks. `--snippets` validates the inline JSON in `policy/*.md` |
| `tools/sync_cfn_policy.py` | Generates each pattern's CloudFormation core-network template from its `baseline.json`, so the policy exists once |

Both are dependency-free. Neither contacts AWS.

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
- `baseline.json` is the single source of truth for a pattern's policy. Terraform reads it
  with `file()`; the CloudFormation template is **generated** from it. Never hand-edit
  `cloudformation/core_network.yaml`.
- Snippets are the default. A new complete example must clear the four-part admission rule
  in [`policy/README.md`](./policy/README.md) and be justified in one line in its table.
- [`CONVENTIONS.md`](./CONVENTIONS.md) is the authoritative contract; [`V2.md`](./V2.md)
  explains why the structure is the way it is.

## Quick-reference facts

| Fact | Value |
|------|-------|
| Control plane / home Region | `us-west-2` |
| Console | AWS Network Manager |
| Policy format | declarative JSON, versioned, change-set gated |
| Policy version used by this repository's patterns | `2025.11` |
| Regional router | Core Network Edge (CNE), one per `edge-location` |
| Inter-CNE routing | automatic full mesh, e-BGP |
| Throughput | up to 100 Gbps per CNE |
| Segment scope | global (one route table across all CNE Regions) |
| Attachments per segment | an attachment belongs to exactly one segment **or** one NFG |
| Attachment types | VPC, Site-to-Site VPN, Direct Connect gateway, Transit Gateway route table, Connect |
| Segment-to-segment | `share` action, **non-transitive** |
| East-west inspection | `send-via` (+ `dual-hop` / `single-hop`) |
| Egress inspection | `send-to` |
| Inspection container | network function group (NFG), a global construct |
| BGP-capable attachments | Site-to-Site VPN, Connect, Direct Connect gateway, TGW peering, CNE-to-CNE |
| Routing policy directions | `inbound`, `outbound` |
| Routing policies on NFGs | **not supported** |
| Overlapping CIDRs | **not supported** (use VPC Lattice / PrivateLink instead) |
| Prefix lists for routing policies | must be created in `us-west-2` |

## Authoritative references

- What is Cloud WAN: https://docs.aws.amazon.com/network-manager/latest/cloudwan/what-is-cloudwan.html
- Core network policies and change sets: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-change-sets.html
- Policy versions and deployment: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-create-policy-version.html
- Service insertion (incl. considerations): https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-service-insertion.html
- Routing policies (incl. key considerations): https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html
- Create a routing policy and rule: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-route-policy.html
- Routing policy example policy document: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-examples-routing-policies.html
- Attachments: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-attachments.html
- Quotas: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html
- Cloud WAN FAQs: https://aws.amazon.com/cloud-wan/faqs/
- This repo — policy guidance: [`policy/`](./policy/) · authoring workflow: [`policy/policy_generator.md`](./policy/policy_generator.md)
- This repo — infrastructure: [`infra/`](./infra/) · catalog: [`blueprint.yaml`](./blueprint.yaml)
- This repo — contract and rationale: [`CONVENTIONS.md`](./CONVENTIONS.md) · [`V2.md`](./V2.md) · [`README.md`](./README.md)
