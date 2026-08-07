# Cloud WAN Network Policy

A Cloud WAN network policy is a **single declarative JSON document** that defines your
entire global network: which Regions have routers, what routing domains exist, how
attachments join them, where traffic is inspected, and how routes are filtered and
manipulated. Everything Cloud WAN does, it does because the policy says so.

This directory teaches that document. It is organised to **mirror the document's own
top-level structure**, so each page maps to a part of the JSON you will write:

| Page | Produces | What it covers |
|------|----------|----------------|
| [`1-core_network_configuration.md`](./1-core_network_configuration.md) | `core-network-configuration` | Edge locations, ASN ranges, ECMP, DNS support, security group referencing |
| [`2-segments.md`](./2-segments.md) | `segments` | Global routing domains, isolation, Region scoping, attachment acceptance |
| [`3-attachment_policies.md`](./3-attachment_policies.md) | `attachment-policies` | How attachments bind to segments: rule numbering, conditions, association methods |
| [`4-segment_sharing.md`](./4-segment_sharing.md) | `segment-actions` (`share`) | Connecting segments, and why sharing is non-transitive |
| [`5-service_insertion.md`](./5-service_insertion.md) | `network-function-groups`, `segment-actions` (`send-to`, `send-via`) | Traffic inspection: egress, east-west, single- vs dual-hop, edge overrides |
| [`6-routing_policies.md`](./6-routing_policies.md) | `routing-policies`, `attachment-routing-policy-rules` | Route filtering, summarization, path preferences, BGP communities |

**Building a policy for your own requirement:** follow
[`policy_generator.md`](./policy_generator.md). It is the workflow — the questions to
answer, the order to assemble the document in, the constraints to check, and how to
validate the result. It works whether you are doing it by hand or driving an AI agent.

**Deploying what you build:** pick an [`infra/`](../infra/) pattern that creates the
attachment types your policy needs, and point it at your document. The infrastructure
is independent of the policy; see [`infra/README.md`](../infra/README.md).

---

## Snippets and examples

Two kinds of code appear here, and the difference matters.

**Snippets** are *fragments* — one array element, or one array. They are illustrative
and are **not deployable on their own**; they slot into a document you assemble. They
live inline in the pages above, next to the prose that explains them. Snippets are the
default, because the value of this section is in the explanation, not in ready-made
documents.

**Examples** are *complete, valid policy documents*. They are deployable against a
named infra pattern and are validated in CI. They live in
[`examples/`](./examples/) and are deliberately rare.

Every fenced ` ```json ` block on these pages is extracted and schema-checked by CI,
so a snippet cannot silently rot into invalid JSON.

### When something earns a full example

An example is justified only when **all four** of these hold:

1. It cannot be understood from the snippets alone — the value is in the *interaction*
   between two or more capabilities.
2. It is deployable end to end against a named infra pattern, so it can be verified
   rather than merely read.
3. It produces a routing outcome that is non-obvious, or that is easy to get wrong
   when composing the snippets by hand.
4. It does **not** differ from an existing example only by parameter values (CIDRs,
   Region names, segment names, community values). Parameterisation is not novelty.

If you cannot write a one-line justification for the table below, what you have is a
snippet. The enforceable version of this rule is in
[`CONVENTIONS.md`](../CONVENTIONS.md).

### Examples

| Example | Infra pattern | Why this earns its place |
|---------|---------------|--------------------------|
| [`filter_then_inspect.json`](./examples/filter_then_inspect.json) | [`2-inspection`](../infra/2-inspection/) (with `-var create_secondary_cidrs=true`) | Route filtering and service insertion interact through a documented Cloud WAN limitation: routing policies **cannot** attach to a network function group, so the filter has to sit at the attachment layer *before* traffic reaches the inspection path. Composing the two snippets by hand naturally produces the version that does not work. |

Deploy it:

```bash
cd infra/2-inspection/terraform
terraform apply \
  -var create_secondary_cidrs=true \
  -var policy_document=../../../policy/examples/filter_then_inspect.json
```

The spoke VPCs get a secondary CIDR outside `10.0.0.0/8`. The policy allows
`10.0.0.0/8` inbound at the VPC attachments and drops everything else, then applies
`send-to` egress inspection and `send-via` dual-hop east-west inspection. So the primary
CIDRs propagate and are inspected, while the secondary CIDRs never enter the segment at
all — observable in `get-network-routes` and in the firewall logs.

![Inspection after filtering](../images/patterns_inspection_after_filtering.png)

### Candidates that did *not* clear the bar

Kept here because "why is there no example for X" is a fair question, and the answers show
the rule working rather than being ignored:

| Candidate | Fails on |
|-----------|----------|
| Centralized egress, east-west dual-hop, east-west single-hop | Criterion 1 — each is a single capability, fully conveyed by the snippets in [`5-service_insertion.md`](./5-service_insertion.md), and each is already what an `infra/` pattern's baseline deploys |
| Route summarization (incl. the per-Region Direct Connect reasoning) | Criterion 2 — verifying it needs a BGP peer to receive the advertisement, which no pattern can provide. The snippets in [`6-routing_policies.md`](./6-routing_policies.md) cover the reasoning in full |
| BGP community segmentation | Criterion 2 — needs an on-premises router setting communities |
| Egress from a Region with no local inspection VPC | Criterion 2 — needs three or more Regions; the patterns deploy two |
| IPv4/IPv6-only segments, peered-TGW IPv4 filtering | Criterion 2 — needs dual-stack spoke VPCs, which no pattern enables |
| Transit Gateway plus service insertion | Criterion 2 — needs inspection added to [`3-transit_gateway`](../infra/3-transit_gateway/), and no shared inspection module ships, so that is a code change rather than a documented variable |

Several of these become admissible the moment the infrastructure supports them — enabling
IPv6 on the spoke VPCs, or a third Region, or a simulated BGP peer. That is the intended
way for this directory to grow: extend a pattern first, then the example has something to
verify against.

---

## Testability matrix

Capabilities are documented independently of any infrastructure. This matrix is about
**what you need to exercise a capability end to end**, not about capabilities being
tied to patterns.

| Capability | Needs | Patterns that provide it |
|------------|-------|--------------------------|
| Segments, attachment policies, sharing | Any two attachments | all |
| Inbound route filtering | Any attachment | all |
| Service insertion (`send-to`, `send-via`) | An inspection attachment in a network function group | `2-inspection` as shipped; `3-transit_gateway` / `4-hybrid` after [adding inspection locally](../infra/README.md) |
| Route summarization | A **BGP-capable** attachment (outbound only) | `3-transit_gateway`, `4-hybrid` |
| Path preferences (AS_PATH, MED, local preference) | A **BGP-capable** attachment | `3-transit_gateway`, `4-hybrid` |
| BGP communities | Site-to-Site VPN or Connect (**not** Direct Connect gateway or TGW peering) | `4-hybrid` |
| Cross-account attachment governance | A shared core network | `5-multi_account` |

Two consequences worth internalising, because they trip up most first designs:

- **Routing policies cannot be attached to a network function group.** If you need to
  filter routes on traffic that is also inspected, filter at the *attachment* layer
  before it enters the inspection path.
- **VPC attachments cannot modify BGP attributes.** Anything involving AS_PATH, MED,
  or local preference needs a BGP-capable attachment.

Both are documented Cloud WAN limitations, both are enforced by
`tools/validate_policy.py`, and the full list is in [`../SKILLS.md`](../SKILLS.md).

---

## Validating a policy

```bash
# Structure, cross-references, and Cloud WAN constraint checks
python3 tools/validate_policy.py my-policy.json

# Also check it against an infra pattern's tagging contract and Regions
python3 tools/validate_policy.py my-policy.json --infra infra/2-inspection
```

The validator is offline and dependency-free. It is not a substitute for the final
gate: Cloud WAN validates a policy when you create a **policy version**, producing a
**change set** that you review and explicitly execute. Nothing changes in your network
until you do, which makes it an effective dry run. Use it for anything destined for a
real network.
