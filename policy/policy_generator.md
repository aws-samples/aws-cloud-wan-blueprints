# Building a Cloud WAN Policy

The workflow for turning a stated requirement into a **validated** Cloud WAN network policy
document. It works whether you are assembling the document by hand from the snippets in
this directory or driving an AI agent.

It is kept separate from [`../SKILLS.md`](../SKILLS.md) on purpose: `SKILLS.md` is the
stable reference for what Cloud WAN *is* and is meant to be lifted into an agent's context
wholesale. This is a *procedure*, and it changes whenever this repository's structure or
tooling changes.

---

## 1. Intake

Answer these before writing any JSON. Most bad Cloud WAN policies come from a skipped
question here rather than from a syntax error.

**Regions**

- Which AWS Regions need a Core Network Edge? Each one bills hourly whether or not it
  carries traffic, so do not list Regions speculatively.
- Are more Regions likely soon? Adding one later is a policy change, not a rebuild — but
  ASN range sizing should leave room.

**Routing domains**

- What are the segments, and what is the axis — environment, business unit, geography?
- Which segments must **not** reach each other? That is the default, so the useful form of
  the question is: which pairs *must* reach each other?
- Within a segment, may attachments reach each other? If not, or if intra-segment traffic
  must be inspected, the segment needs `isolate-attachments: true`.

**Attachments and who owns them**

- Which attachment types: VPC, Site-to-Site VPN, Connect, Direct Connect gateway, Transit
  Gateway route table?
- Are attachments created by the same account that owns the policy? If not, tag-based
  association delegates segment choice across a trust boundary — see the multi-account
  guidance in [`3-attachment_policies.md`](./3-attachment_policies.md).
- Which segments are sensitive enough to need `require-attachment-acceptance: true`?

**Inspection**

- Egress (internet-bound), east-west (between attachments), or both?
- For east-west: inspect in every Region a flow touches (`dual-hop`) or once per path
  (`single-hop`)? Compliance requirements usually decide this, not cost.
- Is there a Region with no local inspection VPC? It needs an edge override.

**Route control**

- Any prefixes that must **not** propagate — secondary CIDRs, pod networks, lab ranges?
- Do on-premises routers need summarised routes rather than every VPC CIDR?
- Multiple paths to the same on-premises prefix that need a preference order?
- Is hybrid traffic separated by BGP community over a shared session?

**How it will be deployed**

- **Which IaC tool — Terraform or CloudFormation?** Ask; do not assume. It does not change
  a single line of the policy, but it changes what you hand back, because the two tools
  consume a policy differently: Terraform reads a JSON file at plan time, while
  CloudFormation needs the policy inline in the template.
- Which [`infra/`](../infra/) pattern, if any, will it be deployed on? That decides which
  attachment tags the `attachment-policies` have to match.

**Ambiguity**

Write down what you assumed. If the requirement did not specify isolation, inspection
direction, or who owns the attachments, those assumptions are the first thing a reviewer
will want to see.

---

## 2. Assembly order

Build the document in the order of the pages in this directory. It is not arbitrary — each
part references the ones before it, so building out of order means rework.

| Step | Page | Produces | Depends on |
|------|------|----------|-----------|
| 1 | [`1-core_network_configuration.md`](./1-core_network_configuration.md) | `core-network-configuration` | — |
| 2 | [`2-segments.md`](./2-segments.md) | `segments` | Edge locations |
| 3 | [`3-attachment_policies.md`](./3-attachment_policies.md) | `attachment-policies` | Segments, and the network function group if inspecting |
| 4 | [`4-segment_sharing.md`](./4-segment_sharing.md) | `segment-actions` (`share`) | Segments |
| 5 | [`5-service_insertion.md`](./5-service_insertion.md) | `network-function-groups`, `segment-actions` (`send-to`, `send-via`) | Segments, and isolation set correctly in step 2 |
| 6 | [`6-routing_policies.md`](./6-routing_policies.md) | `routing-policies`, `attachment-routing-policy-rules` | Everything above |

Two ordering traps worth naming:

- **Isolation is decided in step 2 but required by step 5.** If you add `send-via` for
  intra-segment traffic later, go back and set `isolate-attachments: true`. Forgetting this
  produces a policy that deploys and silently bypasses the firewall.
- **The network function group is declared in step 5 but referenced in step 3.** The
  attachment policy that puts inspection VPCs into the group needs a *low* rule number, or
  a later `tag-exists: domain` rule claims them first.

---

## 3. Constraint checklist

Check the draft against these before validating. Each corresponds to a check in
`tools/validate_policy.py`, so this list and the validator stay in step.

**Will it deploy?**

- [ ] Every segment referenced by a segment action or attachment policy is declared (`ref-1`)
- [ ] Every network function group referenced is declared (`ref-2`)
- [ ] Every Region in `with-edge-overrides` is a declared edge location (`ref-4`)
- [ ] Every routing policy name referenced is declared (`ref-5`)
- [ ] Rule numbers are unique in each numbered array (`cwan-3`, `cwan-5`)
- [ ] Routing-policy ASNs do not overlap the core network `asn-ranges` (`cwan-6`)

**Will it do what you meant?**

- [ ] `allow` rules have a **lower** rule number than any catch-all `drop` (`cwan-3`)
- [ ] Segments with intra-segment `send-via` inspection are **isolated** (`cwan-8`)
- [ ] `dual-hop` is only used where inspection exists in every participating Region (`cwan-9`)
- [ ] No routing policy is attached to a network function group (`cwan-7`)
- [ ] `summarize` actions are `outbound` and target BGP-capable attachments (`cwan-10`)
- [ ] BGP communities are not expected on Direct Connect gateway or TGW peering (`cwan-11`)
- [ ] No BGP attribute modification is aimed at a VPC attachment (`cwan-12`)
- [ ] Prefix lists referenced by routing policies exist in `us-west-2` (`cwan-13`)
- [ ] Every tag the infrastructure applies is matched by an attachment policy (`cwan-14`)
- [ ] Edge locations match the Regions the infrastructure deploys (`cwan-14`)

**Did you check the right thing afterwards?**

- [ ] Verification uses `get-network-routes`, **not**
      `list-core-network-routing-information` — the latter shows state *before* routing
      policies are applied

---

## 4. Validate

Offline, in order of cost:

```bash
# Structure, cross-references, and the Cloud WAN constraint checks
python3 tools/validate_policy.py my-policy.json

# Also check the tagging contract and Regions of the pattern you intend to deploy on
python3 tools/validate_policy.py my-policy.json --infra infra/2-inspection
```

Errors must be fixed. Warnings name a constraint the policy alone cannot prove — for
example whether a routing-policy label lands on a BGP-capable attachment — so read each
one and confirm it holds in your environment rather than dismissing it.

Then the authoritative gate, which needs an account:

```bash
aws networkmanager put-core-network-policy \
  --core-network-id <id> \
  --policy-document file://my-policy.json
```

Creating a policy **version** produces a **change set** that Cloud WAN validates
server-side. **Nothing changes until you execute it**, which makes this a genuine dry run.
Review the change set, then deploy it. For anything destined for a real network this step
is not optional.

---

## 5. What to hand back

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

**2. Which infra pattern to deploy, and why.** It must create the attachment types the
policy needs:

| If the policy needs | Deploy |
|---------------------|--------|
| VPC attachments only | [`1-basic`](../infra/1-basic/) |
| A network function group (any inspection) | [`2-inspection`](../infra/2-inspection/) |
| Transit Gateway route-table attachments | [`3-transit_gateway`](../infra/3-transit_gateway/) |
| Any BGP capability, or hybrid attachments | [`4-hybrid`](../infra/4-hybrid/) |
| A core network shared across accounts | [`5-multi_account`](../infra/5-multi_account/) |

**3. The residual manual steps a policy cannot express.** These are the usual reason a
correct policy still does not work:

- **Appliance mode** on the inspection VPC attachment, or return traffic is asymmetric and
  flows drop.
- **Managed prefix lists created in `us-west-2`** and associated with the core network,
  for any summarization policy.
- **Routing-policy labels** applied to the attachments the `attachment-routing-policy-rules`
  target.
- **On-premises BGP configuration** — which prefixes are advertised, which communities are
  set, which ASNs are used.
- **Direct Connect circuits and virtual interfaces**, which cannot be simulated.

**4. The assumptions you made** wherever the requirement was ambiguous.

**5. What cannot be observed in this environment.** Most commonly: with a two-Region
deployment, `single-hop` and `dual-hop` behave almost identically because there is one
Region pair. Say so rather than letting someone conclude the policy is wrong.

---

## Worked example

> *"Two Regions. Production and development must not talk to each other. All
> internet-bound traffic must be inspected, and so must anything entering or leaving
> production. Our Kubernetes pod CIDRs must not leak into the wider network."*

**Intake.** Two Regions. Segments `production`, `development`. No sharing between them.
Egress inspection for both. East-west inspection for `production`, including
production-to-production — so `production` must be isolated. Pod CIDRs are a filtering
requirement at the VPC attachment layer, and VPC attachments only support `inbound`.

**Assembly.** Steps 1–3 give the two Regions, the two segments with `production` isolated,
the network function group, and attachment policies (inspection tag first, then the
`domain` tag). Step 4 adds nothing — no sharing is wanted. Step 5 adds `send-to` for both
segments and `send-via` `dual-hop` for `production`. Step 6 adds an inbound allow-list at
the VPC attachments.

**Constraint check.** The filter cannot attach to the network function group (`cwan-7`), so
it goes at the attachment layer — which is also where it has to be, since the pod CIDRs
should never enter the segment. `production` is isolated, satisfying `cwan-8`. `dual-hop`
needs inspection in both Regions, which the chosen pattern provides.

**Result.** That is
[`examples/filter_then_inspect.json`](./examples/filter_then_inspect.json), deployed on
[`2-inspection`](../infra/2-inspection/) with `-var create_secondary_cidrs=true`.

**Hand back.** The policy, the pattern and its variable, appliance mode as a prerequisite,
the label `vpcAttachments` to apply to the spoke attachments, and the note that with two
Regions `dual-hop` is not visibly different from `single-hop`.
