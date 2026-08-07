# Attachment Policies

Produces the **`attachment-policies`** array — the rules that decide, automatically,
which segment or network function group a new attachment joins.

This is where most Cloud WAN designs break, and the failure is quiet. The attachment
reaches `AVAILABLE`, the console shows no error, and it simply never associates with
anything. Nothing routes, and there is no message telling you why. That is why this gets
its own page.

```json
{
  "attachment-policies": [
    {
      "rule-number": 100,
      "condition-logic": "and",
      "conditions": [
        { "type": "attachment-type", "operator": "equals", "value": "vpc" },
        { "type": "tag-exists", "key": "domain" }
      ],
      "action": {
        "association-method": "tag",
        "tag-value-of-key": "domain"
      }
    }
  ]
}
```

Read that as: *any VPC attachment carrying a `domain` tag joins the segment named by
that tag's value.* One rule, and every VPC in the estate self-associates. That is the
whole idea — attachment policies are what make Cloud WAN self-service.

## Rule evaluation: numbered, ordered, first match wins

Rules are evaluated in ascending `rule-number` and **the first match wins**. Later rules
never see an attachment that an earlier rule claimed.

Two consequences:

- **Put specific rules before general ones.** A catch-all at rule 100 makes every
  subsequent rule dead.
- **Leave numbering room.** Conventionally rules step by 100 (`100`, `200`, `300`) so you
  can insert `150` later without renumbering. Renumbering is where mistakes creep in.

Rule numbers must be unique. `tools/validate_policy.py` rejects duplicates (`cwan-3`),
because a duplicate silently shadows one of the two rules.

## Conditions

| Type | Matches on | Example use |
|------|-----------|-------------|
| `tag-exists` | Presence of a tag key | "any VPC that declares a `domain`" |
| `tag-value` | A tag key **and** value | "the inspection VPCs" |
| `attachment-type` | `vpc`, `site-to-site-vpn`, `connect`, `direct-connect-gateway`, `transit-gateway-route-table` | "all hybrid connectivity" |
| `account-id` | The AWS account that owns the attachment | "only the platform team's account may join `production`" |
| `region` | The Region the attachment is in | "European VPCs go to the EMEA segment" |

`condition-logic` combines them: `and` requires every condition, `or` requires any.

```json
{
  "rule-number": 100,
  "condition-logic": "and",
  "conditions": [
    { "type": "attachment-type", "operator": "equals", "value": "vpc" },
    { "type": "region", "operator": "equals", "value": "eu-west-1" }
  ],
  "action": { "association-method": "constant", "segment": "emea" }
}
```

## Association methods

### `constant` — a fixed destination

```json
{
  "rule-number": 200,
  "condition-logic": "or",
  "conditions": [
    { "type": "attachment-type", "operator": "equals", "value": "site-to-site-vpn" },
    { "type": "attachment-type", "operator": "equals", "value": "connect" },
    { "type": "attachment-type", "operator": "equals", "value": "direct-connect-gateway" }
  ],
  "action": { "association-method": "constant", "segment": "hybrid" }
}
```

Everything matching goes to one named segment. Use it when the destination is a property
of the *rule*, not of the attachment.

### `tag` — the attachment names its own segment

```json
{
  "action": {
    "association-method": "tag",
    "tag-value-of-key": "domain"
  }
}
```

The segment is whatever the tag's value says. One rule covers unlimited segments, and
adding a new segment needs no attachment-policy change — just the segment declaration
and a correspondingly tagged attachment.

This is powerful and it is a **delegation of authority**: whoever sets the tag chooses
the routing domain. Fine inside one account. Across accounts, pair it with
`account-id` conditions and `require-attachment-acceptance` (see below).

### `add-to-network-function-group` — inspection attachments

```json
{
  "rule-number": 100,
  "condition-logic": "or",
  "conditions": [
    { "type": "tag-value", "operator": "equals", "key": "inspection", "value": "true" }
  ],
  "action": { "add-to-network-function-group": "inspectionVpcs" }
}
```

An attachment goes into a segment **or** a network function group, never both — so this
rule must come *before* any rule that would otherwise claim the inspection VPC. In
practice that means the inspection rule gets a low rule number.

## Tag or attachment type? A rule worth internalising

This repository's [tagging contract](../infra/README.md#attachment-tags)
binds VPCs by tag but hybrid attachments by type. That asymmetry is deliberate, and it
generalises:

> **Use a tag when the destination is a choice.** A VPC could legitimately belong to
> `production`, `development`, or `shared`. Nothing about the VPC itself reveals which,
> so its owner declares the intent with a tag.
>
> **Use `attachment-type` when the type *is* the intent.** A Direct Connect gateway
> attachment is hybrid connectivity by definition. There is no choice to express, so
> requiring a tag would add a step that can only be got wrong.

Applied to the full attachment set:

| Attachment | Bind by | Why |
|------------|---------|-----|
| VPC | `domain` tag | Segment is a choice its owner makes |
| Transit Gateway route table | `domain` tag | Same — a TGW route table maps to a routing domain you choose |
| Inspection VPC | `inspection = true` tag | It is a *role*, not a type — an inspection VPC is still a `vpc` |
| Site-to-Site VPN | `attachment-type` | The type is the intent |
| Connect | `attachment-type` | The type is the intent |
| Direct Connect gateway | `attachment-type` | The type is the intent |

Note the inspection VPC: type-based matching cannot distinguish it from a spoke VPC, so
role tagging is the only option. This is why `2-inspection`'s baseline needs both a
`tag-value` rule and a `tag-exists` rule.

## A complete, realistic set

Ordered so specific rules precede general ones:

```json
{
  "attachment-policies": [
    {
      "rule-number": 100,
      "condition-logic": "or",
      "conditions": [
        { "type": "tag-value", "operator": "equals", "key": "inspection", "value": "true" }
      ],
      "action": { "add-to-network-function-group": "inspectionVpcs" }
    },
    {
      "rule-number": 200,
      "condition-logic": "or",
      "conditions": [
        { "type": "attachment-type", "operator": "equals", "value": "site-to-site-vpn" },
        { "type": "attachment-type", "operator": "equals", "value": "connect" },
        { "type": "attachment-type", "operator": "equals", "value": "direct-connect-gateway" }
      ],
      "action": { "association-method": "constant", "segment": "hybrid" }
    },
    {
      "rule-number": 300,
      "condition-logic": "and",
      "conditions": [
        { "type": "tag-exists", "key": "domain" },
        { "type": "account-id", "operator": "equals", "value": "111122223333" }
      ],
      "action": { "association-method": "tag", "tag-value-of-key": "domain" }
    }
  ]
}
```

Rule 100 claims inspection VPCs before anything else can. Rule 200 catches all hybrid
connectivity by type. Rule 300 does tag-based self-service, but **only for one
account** — an attachment from anywhere else matches nothing and associates with
nothing, which is the safe failure.

## Defensive design for shared core networks

In a shared core network the attachment is created by another account, and with
`association-method: tag` **the tag is set by that account**. Tag-based association
therefore delegates segment choice across a trust boundary.

Three ways to keep that safe:

1. **Constrain by `account-id`** — as rule 300 above. A tag from an unexpected account
   matches nothing.
2. **`require-attachment-acceptance: true`** on sensitive segments, so a human approves
   the association ([`2-segments.md`](./2-segments.md)).
3. **Use `constant` for sensitive segments** — `production` gets an explicit rule keyed
   on account and Region, and only non-sensitive segments use tag-based self-service.

See [`infra/5-multi_account`](../infra/5-multi_account/).

## Debugging an attachment that never associates

The symptom is an attachment in `AVAILABLE` with no segment. Work through this in order:

1. **Does any rule match?** Compare the attachment's tags and type against every rule.
   The most common cause is a tag key mismatch — `Domain` vs `domain`, or a tag applied
   to the VPC instead of to the attachment.
2. **Is an earlier rule claiming it?** First match wins. An attachment you expected rule
   300 to handle may have been taken by rule 100.
3. **For `association-method: tag`, does the segment exist?** The tag value must name a
   declared segment exactly. `domain = prod` when the segment is `production` matches the
   rule and then fails to associate.
4. **Is the segment restricted by `edge-locations`?** An attachment outside those Regions
   cannot associate.
5. **Is it awaiting acceptance?** With `require-attachment-acceptance: true` the
   attachment sits pending until approved.
6. **Is the policy LIVE?** A policy version that was created but never executed is not
   in effect. Check the change set state.

Points 1 and 3 are checkable offline, which is what `cwan-14` does:

```bash
python3 tools/validate_policy.py my-policy.json --infra infra/2-inspection
```

It confirms that every tag the infrastructure applies is matched by some rule, and it is
worth running before every deploy — it turns the quietest failure mode in Cloud WAN into
a build error.

## Constraints to carry forward

| Constraint | Consequence |
|------------|-------------|
| First matching rule wins | Order specific before general |
| Rule numbers must be unique | Enforced by `cwan-3` |
| An attachment joins a segment **or** an NFG | Inspection rules must precede segment rules |
| `association-method: tag` requires the value to name a real segment | Otherwise the rule matches and association still fails |
| Tags are set by the **attachment owner** | In shared core networks, constrain by `account-id` too |
| Attachment policies are applied **before** segment sharing | Association first, reachability second |
| Pending attachments cannot reach the core network | Acceptance gates connectivity, not creation |

## Next

[`4-segment_sharing.md`](./4-segment_sharing.md) — now that attachments are in segments,
deciding which segments may reach each other.

## Reference

- [Core network policy parameters](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html)
- [Attachments](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-attachments.html)
