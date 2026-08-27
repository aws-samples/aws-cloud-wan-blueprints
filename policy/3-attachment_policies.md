---
title: "Cloud WAN attachment policies: automatic attachment association by tag, attachment type, account or Region"
description: "How AWS Cloud WAN attachment policies map each attachment to a segment or network function group automatically, so a workload team onboards without a central ticket. Covers every match condition — tag-exists, tag-value, attachment-type, account, region and resource-id — first-match-wins rule ordering, association-method constant versus tag, add-to-network-function-group for inspection VPCs, require-acceptance, and who controls the tags in a shared core network."
---

# Attachment policies

[Attachment policies](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html#cloudwan-attach-policies-json) map an attachment to a segment or to a network function group. Rather than associating each one by hand, you declare the intent once and every attachment that matches lands where it belongs — which is what makes AWS Cloud WAN self-service.

> **When you match on tags, they are the tags on the attachment** — not on the resource behind it. Those tags also travel with the attachment, so in a shared core network a tag set by the spoke account is what the core network's rules evaluate. That is what makes cross-account self-service work, and it is why tag-based association raises the question of [who controls the tags](#who-controls-the-tags-in-a-shared-core-network).

The `attachment-policies` array is optional, and each rule in it takes five fields:

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `rule-number` | Processing order, from `1` to `65535` | Yes | — |
| `description` | A free-text description | No | — |
| `condition-logic` | Whether conditions combine with `and` or `or` | Only with more than one condition | — |
| `conditions` | What the rule matches on | Yes | — |
| `action` | What happens when it matches | Yes | — |

> **An attachment that matches no rule associates with nothing.** It reaches `AVAILABLE`, reports no error, and simply never joins a segment or network function group — so tag spelling and rule order are worth checking before you deploy.

## `rule-number` and `description`

Rules are evaluated in ascending `rule-number` and **the first match wins** — no rule after it is processed. So specific rules go before general ones: a catch-all placed early makes everything after it unreachable. Leave numbering room too. Stepping by 100 lets you slot a rule in at 150 later, instead of renumbering its neighbours and changing what they match.

```json
{
  "rule-number": 100,
  "description": "Spoke VPC association based on their `domain` tag"
}
```

A description costs nothing. Rules get read most closely when something has not associated, and *which of these was meant to catch this attachment* is far easier to answer when each rule says so.

## `condition-logic` and `conditions`

`condition-logic` is mandatory once a rule has more than one condition: `and` requires all of them, `or` requires any. Conditions are unordered and nesting is not supported, so one `and` or one `or` governs the whole rule.

| Type | Matches on | Operators | Associates to |
|------|-----------|-----------|---------------|
| `any` | Anything. Used for a deliberate catch-all | — | Segment |
| `attachment-type` | `vpc`, `site-to-site-vpn`, `connect`, `direct-connect-gateway`, `transit-gateway-route-table` | `equals`, `not-equals`, `contains`, `begins-with` | Segment |
| `account` | The AWS account that created the attachment | same | Segment |
| `region` | The Region the attachment is in | same | Segment |
| `resource-id` | The resource behind it, such as a VPC ID | same | Segment |
| `tag-exists` | A tag key is present, whatever its value | — (takes `key`) | Segment, network function group |
| `tag-name` | Also key presence, without evaluating the value | — | Segment, network function group |
| `tag-value` | A tag key and its value | `equals`, `not-equals`, `contains`, `begins-with` | Segment, network function group |

Only the tag conditions reach a network function group, and those rules are constrained further: [`condition-logic` must be `and`](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-attachments.html) even where there is a single condition, and every condition must be tag-based. The AWS documentation is inconsistent on how many: one page asks for `tag-exists` alongside a `tag-name` or `tag-value` condition, another gives those two as the only supported types. Their own examples use a single tag condition, so start there and add `tag-exists` if policy generation objects. Segment rules carry no such restriction.

```json
{
  "rule-number": 100,
  "condition-logic": "and",
  "conditions": [
    {
      "type": "attachment-type",
      "operator": "equals",
      "value": "vpc"
    },
    {
      "type": "region",
      "operator": "begins-with",
      "value": "eu-"
    }
  ],
  "action": {
    "association-method": "constant",
    "segment": "europe"
  }
}
```

Look past `equals`. `begins-with` on `region`, as above, covers every European Region without listing them, and keeps working when a new one launches. `not-equals` inverts a rule cheaply where the exceptions are fewer than the matches.

`resource-id` pins a rule to one resource, so every new attachment means editing the LIVE policy. Reach for it only where a single resource genuinely needs its own treatment.

## `action`

What happens when the rule matches. An attachment gets exactly one destination: a segment **or** a network function group, never both, and never more than one of either.

| Field | Use |
|-------|-----|
| `association-method` | `constant` names the segment in the rule; `tag` reads it from an attachment tag's value |
| `segment` | The segment name — with `constant` only |
| `tag-value-of-key` | The tag key whose *value* names the segment — with `tag` only |
| `add-to-network-function-group` | Join a network function group instead of a segment |
| `require-acceptance` | Override the segment's acceptance setting for this rule |

1. **`constant`** puts everything the rule matches into one named segment. Use it where the destination is a property of the rule rather than of the attachment.

```json
{
  "association-method": "constant",
  "segment": "hybrid"
}
```

2. **`tag`** lets the attachment name its own segment. `tag-value-of-key` gives the tag key to read, and that tag's **value must match a declared segment name exactly**.

```json
{
  "association-method": "tag",
  "tag-value-of-key": "domain"
}
```

The leverage is in that pairing. Agree a tagging convention — one key whose value is always a segment name — and a single rule associates the whole estate: `domain = production` goes to `production`, `domain = development` to `development`, and a segment you add next year needs no change here at all. Without the convention you write a near-identical `constant` rule per segment, and edit all of them whenever the set of segments changes. [VPCs choose their own segment](#tag-based-attachment-policy-vpcs-choose-their-own-segment-with-association-method-tag) works through this.

3. **`add-to-network-function-group`** sends the attachment to a group instead, under the narrower conditions described at the top of this page.

```json
{
  "add-to-network-function-group": "inspectionVpcs"
}
```

4. **`require-acceptance`** adds manual approval to a single rule.

```json
{
  "association-method": "tag",
  "tag-value-of-key": "domain",
  "require-acceptance": true
}
```

Only `true` is valid. Attachments this rule matches then wait for approval even where the segment does not require it. The reverse is not possible — a rule cannot waive acceptance the segment requires — so use it to gate one Region or one account while the rest stays self-service.

## Who controls the tags in a shared core network?

The rules are yours — as core network owner you decide which tags map an attachment to a specific segment or network function group. The tags are not: in a shared core network the attachment owner sets them and can change them at any time, so an attachment can move segment, or stop associating altogether, without the policy changing.

This applies to any rule that depends on tags, and we recommend three ways to keep it safe (best first):

1. **Govern the tags themselves.** Use [service control policies](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html) in AWS Organizations to control who may set the tag keys your rules match on. Match on a tag a spoke account cannot change and the exposure goes away. It is the only option that removes the problem rather than compensating for it, and the network stays automatic.
2. **Require acceptance.** Either on the segment, or per rule with `require-acceptance`. Effective, but it puts a manual step into an otherwise dynamic network, so prefer it where a human decision is genuinely wanted.
3. **Pin the exceptions to accounts.** For one or two genuinely sensitive segments, a `constant` rule keyed on `account` takes tags out of the decision altogether — see [An external partner gets its own segment](#account-conditions-with-association-method-constant-an-external-partner-gets-its-own-segment). Do not plan on using it widely: conditions match a specific account ID, with no equivalent for an organization or an OU, so it is one rule per account.

## Attachment policy examples: association by tag, `attachment-type`, `account` and `region`

### Tag-based attachment policy: VPCs choose their own segment with `association-method: tag`

```json
{
  "rule-number": 300,
  "condition-logic": "and",
  "conditions": [
    {
      "type": "attachment-type",
      "operator": "equals",
      "value": "vpc"
    },
    {
      "type": "tag-exists",
      "key": "domain"
    }
  ],
  "action": {
    "association-method": "tag",
    "tag-value-of-key": "domain"
  }
}
```

Any VPC attachment tagged `domain` joins the segment its value names — `domain = production` lands in `production`. One rule serves every segment you ever declare, and onboarding a workload becomes a tag rather than a policy change. A VPC with no `domain` tag matches nothing and associates with nothing, which is the safe failure.

### `attachment-type` conditions: hybrid connectivity always lands in one segment

```json
{
  "rule-number": 200,
  "condition-logic": "or",
  "conditions": [
    {
      "type": "attachment-type",
      "operator": "equals",
      "value": "site-to-site-vpn"
    },
    {
      "type": "attachment-type",
      "operator": "equals",
      "value": "direct-connect-gateway"
    },
    {
      "type": "attachment-type",
      "operator": "equals",
      "value": "connect"
    }
  ],
  "action": {
    "association-method": "constant",
    "segment": "hybrid"
  }
}
```

Every hybrid attachment type goes to `hybrid`, with no tag involved — `or` is what lets one rule cover three types. Nothing is delegated here: the segment is fixed in the rule, so an attachment owner cannot place a VPN into `production` by tagging it.

### `account` conditions with `association-method: constant`: an external partner gets its own segment

```json
{
  "rule-number": 150,
  "condition-logic": "or",
  "conditions": [
    {
      "type": "account",
      "operator": "equals",
      "value": "111122223333"
    }
  ],
  "action": {
    "association-method": "constant",
    "segment": "external",
    "require-acceptance": true
  }
}
```

Anything attached from that account lands in `external` whatever it is tagged, and waits for approval first.

This is the pattern for third parties needing layer 3 reachability — a SaaS provider, a partner, an acquisition not yet integrated. You cannot govern how they tag, so do not let tags decide: pin the destination with `constant`, key the rule on the account, and put the security you need around that one segment. Isolate it, share it only with what it must reach, or inspect traffic crossing into it. The rule number matters as much as the conditions: it has to sit ahead of any broader rule that could also match, or the partner's own tags still get a say in where it lands.

### `add-to-network-function-group`: inspection VPCs join a network function group

```json
{
  "rule-number": 100,
  "condition-logic": "and",
  "conditions": [
    {
      "type": "tag-value",
      "operator": "equals",
      "key": "inspection",
      "value": "true"
    }
  ],
  "action": {
    "add-to-network-function-group": "inspectionVpcs"
  }
}
```

An inspection VPC is still a `vpc`, so any broader rule matching that type would claim it and associate it to a segment — where it cannot be a service insertion target. The low rule number is doing the work, claiming the attachment before any segment rule gets to see it. The condition matches the tag's value and not just its key, so only an attachment tagged `inspection = true` joins the group.

### `region` conditions with `require-acceptance`: one Region needs a human, the rest do not

```json
{
  "rule-number": 250,
  "condition-logic": "and",
  "conditions": [
    {
      "type": "attachment-type",
      "operator": "equals",
      "value": "vpc"
    },
    {
      "type": "tag-exists",
      "key": "domain"
    },
    {
      "type": "region",
      "operator": "equals",
      "value": "us-east-2"
    }
  ],
  "action": {
    "association-method": "tag",
    "tag-value-of-key": "domain",
    "require-acceptance": true
  }
}
```

VPC attachments carrying a `domain` tag still pick their own segment, but those in `us-east-2` wait for a human first. A narrowing rule like this needs a lower number than the broader rule it carves the exception out of, otherwise the broader rule matches and the exception never runs.
