---
title: "Cloud WAN attachment routing policy rules: binding routing policies to attachments with labels"
description: "How attachment-routing-policy-rules associate AWS Cloud WAN routing policies with attachments through a routing-policy label, what inbound and outbound mean at attachment scope, and how edge-locations scopes a rule so one Direct Connect gateway attachment carries different routing policies per CNE. Includes the cross-account ordering problem when the attachment owner cannot set its own label."
---

# Attachment routing policy rules

The [`attachment-routing-policy-rules`](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html#cloudwan-attachment-routing-policy-rules-json) array associates existing [routing policies](./7-routing_policies.md) with attachments. The array is optional and requires policy [`version`](./1-core_network_version_configuration.md#version) `2025.11` or later. Every name in `associate-routing-policies` must be defined in [`routing-policies`](./7-routing_policies.md).

> **For an inbound policy, attachment scope is the first control point.** A matching `drop` prevents a route learned from that attachment from entering the core network. An outbound policy instead controls what the core network advertises to that attachment.

Each rule has a `rule-number`, `conditions`, and an `action`. Its conditions match an attachment's routing-policy label. Set that label separately, either when creating the attachment or through the label API; until it is present, no rule can match the attachment.

Every field a rule accepts:

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `rule-number` | Processing order, from `1` to `65535` — lowest first | Yes | — |
| `description` | A free-text description | No | — |
| `edge-locations` | Limits the rule to named CNE Regions | No | All CNE Regions for a Direct Connect attachment |
| `conditions` | The routing-policy label to match | Yes | — |
| `action` | The routing policies to associate | Yes | — |

## `rule-number` and `description`

Rules are processed in ascending `rule-number`. Leave gaps between numbers — for example, `100`, `200`, and `300` — so a later rule can be inserted without renumbering the existing policy.

```json
{
  "rule-number": 100,
  "description": "Filter the VPC secondary CIDR"
}
```

Use `description` to state the routing treatment the rule assigns. It makes the intended label-to-policy mapping easier to identify when reviewing or troubleshooting an attachment.

## `conditions`

`routing-policy-label` is the only condition type. Think of the label as an attachment's routing-treatment name: each attachment has one label, and the label determines which attachment-routing rules apply.

A rule can accept one or more labels. Any listed label matches. Because an attachment has one label, two attachments that need different treatment need different labels. One attachment can still be treated differently per Region, though: several rules may match the same label, and [`edge-locations`](#edge-locations) below decides where each applies.

```json
{
  "rule-number": 100,
  "description": "Apply VPC secondary CIDR filters",
  "conditions": [
    {
      "type": "routing-policy-label",
      "value": "vpcAttachments"
    }
  ]
}
```

## `action`

`associate-routing-policies` accepts one or more routing-policy names and associates all of them with every attachment that matches the rule:

```json
{
  "rule-number": 100,
  "conditions": [
    {
      "type": "routing-policy-label",
      "value": "vpcAttachments"
    }
  ],
  "action": {
    "associate-routing-policies": [
      "dropVpcSecondaryIpv4Cidr",
      "dropVpcSecondaryIpv6Cidr"
    ]
  }
}
```

The attachment rule selects **which attachments** receive the policies. In this example, the `vpcAttachments` label selects the VPC attachments that receive them. Each referenced policy selects **which direction** it controls:

| Policy direction | At attachment scope |
|------------------|---------------------|
| `inbound` | Routes learned from the attachment into the core network |
| `outbound` | Routes advertised from the core network to the attachment |

> **Direction belongs to the routing policy, not to `attachment-routing-policy-rules`.** To govern both flows, associate one inbound policy and one outbound policy. Policy capabilities still depend on attachment type: [BGP-capable attachments support the full action set, while VPC attachments support inbound filtering only](./7-routing_policies.md#routing-policy-direction).

## `edge-locations`

`edge-locations` limits a matching rule's policy association to selected CNE Regions. It is useful for Direct Connect gateway attachments, which can associate with multiple CNEs. Without the field, a matching policy applies at every CNE associated with the attachment; with it, the policy applies only at the listed Regions.

### Different routing policies per CNE on one attachment

When several rules match the same label, each rule is honoured independently, at the Regions its own `edge-locations` names. That is what gives one attachment different routing treatment per CNE — and it matters most for the Direct Connect gateway attachment, the type that associates with multiple CNEs:

```json
[
  {
    "rule-number": 100,
    "description": "N. Virginia: global filter plus AS_PATH prepend to de-prefer this Region's path to on-premises",
    "edge-locations": ["us-east-1"],
    "conditions": [
      {
        "type": "routing-policy-label",
        "value": "dxAttachment"
      }
    ],
    "action": {
      "associate-routing-policies": ["filterDecommissionedRoutes", "depreferNVirginiaPath"]
    }
  },
  {
    "rule-number": 200,
    "description": "Ireland: global filter only",
    "edge-locations": ["eu-west-1"],
    "conditions": [
      {
        "type": "routing-policy-label",
        "value": "dxAttachment"
      }
    ],
    "action": {
      "associate-routing-policies": ["filterDecommissionedRoutes"]
    }
  }
]
```

Both rules match the `dxAttachment` label, so both apply — each at the Regions it names. Rules do not merge: a rule associates exactly what its action lists, so a policy meant for every CNE is repeated in every action, as `filterDecommissionedRoutes` is here. `depreferNVirginiaPath` applies only at `us-east-1` — there it could, for example, prepend AS_PATH to the on-premises routes learned at that CNE, so traffic toward on-premises prefers the Ireland path with N. Virginia as failover.

> **Labels distinguish attachments; `edge-locations` distinguishes Regions.** Only the Direct Connect gateway *needs* this — one attachment, one label, several CNEs. For single-Region types it is a convention choice: one stable label plus Region-scoped rules keeps regional variation in the policy document, instead of encoding Regions into labels and re-labeling live attachments when treatment changes. Two attachments in the same Region that need different treatment still need different labels.

Two things complete the picture. Where a rule binds several policies at the same CNE — `us-east-1` above — their [`routing-policy-number`](./7-routing_policies.md#routing-policy-number-running-multiple-policies-on-the-same-resource) orders them, per CNE. And direction still belongs to each policy, not to the rule: both policies here happen to act inbound, on routes learned from the attachment — an outbound policy binds exactly the same way.

> **A Region no rule covers gets no policies — silently.** Add a Region to the core network later and the Direct Connect gateway attachment extends there, but no rule names it, so routes at that CNE flow unfiltered and unmodified, with no error anywhere. Review the rule set whenever `edge-locations` change — in the policy document or on the attachment.

## Creation-time dependency

> **The attachment owner cannot set its routing-policy label.** In a cross-account core network, the spoke account creates the attachment, while the core-network owner applies the label.

An attachment can satisfy an `attachment-policies` rule and associate with its segment before the core-network owner can apply its routing-policy label. If the routing policy must apply from the moment of segment association, creation, label assignment, and association need coordinated ordering.

[Apply the label before association](https://repost.aws/articles/AR-FsTwlLJTtuEBmBF4TjSOw/applying-aws-cloud-wan-routing-policy-labels-to-cross-account-attachments-at-creation-time) by either deferring segment association with a centrally protected validation tag until automation sets the label, or by requiring attachment acceptance and assigning the label before accepting the attachment.

> **Treat a routing-policy label as routing control.** Changing or removing it can change the policies associated with the attachment. Grant the label API only to the operators who should make that change, and verify the resulting post-policy routing state.
