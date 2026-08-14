# Cloud WAN Network Policy

This section is a capability reference for building an AWS Cloud WAN core network policy document. It explains the available policy constructs, their dependencies, and the decisions that commonly affect a design. It complements, but does not replace, the [AWS Cloud WAN documentation](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policy-documents.html).

## What it covers

The pages follow the structure of a policy document. Use them to understand the JSON area that implements each part of your design:

| Page | Produces | What it covers |
|------|----------|----------------|
| [`1-core_network_version_configuration.md`](./1-core_network_version_configuration.md) | `core-network-configuration` | Edge locations, ASN ranges, ECMP, DNS support, and security-group referencing |
| [`2-segments-and-nfg.md`](./2-segments-and-nfg.md) | `segments` | Global routing domains, isolation, Region scope, and attachment acceptance |
| [`3-attachment_policies.md`](./3-attachment_policies.md) | `attachment-policies` | How attachments join segments or network function groups |
| [`4-segment_sharing.md`](./4-segment_sharing.md) | `segment-actions` (`share`) | Route exchange between segments |
| [`5-service_insertion.md`](./5-service_insertion.md) | `network-function-groups`, `segment-actions` (`send-to`, `send-via`) | Egress and east-west traffic inspection |
| [`6-static_routes.md`](./6-static_routes.md) | `segment-actions` (`create-route`) | Explicit attachment routes and blackholes |
| [`7-routing_policies.md`](./7-routing_policies.md) | `routing-policies` | Route filtering, summarization, path preferences, and BGP communities |
| [`8-edge_location_associations.md`](./8-edge_location_associations.md) | `segment-actions` (`associate-routing-policy`) | Routing-policy association between Core Network Edge pairs |
| [`9-attachment_routing_policy_rules.md`](./9-attachment_routing_policy_rules.md) | `attachment-routing-policy-rules` | Routing-policy association with labelled attachments |

## Use this reference to build a policy

The JSON examples in these pages are **composable snippets**, not complete deployable policies. A snippet illustrates one construct in the context needed to explain it; assemble the complete document from the constructs that match your own topology, attachment types, Regions, and routing requirements.

This is intentional. A full policy would encode one topology's decisions and is not a template for every network. The snippets let you understand and compose the policy you need without inheriting assumptions from an unrelated example.

For a guided workflow, use the [policy-generator capability in `SKILLS.md`](../SKILLS.md#building-a-policy). The capability is intended for use with an AI agent: the agent uses this directory as its knowledge base to translate requirements into Cloud WAN constructs, assemble a complete policy in dependency order, apply the constraint checklist, and select appropriate infrastructure and validation steps. You can follow the same workflow by hand, but the capability is optimized to automate those steps with an agent.

## Validating a policy

Use the policy-generator capability with an agent to validate or troubleshoot a policy. Give the agent the intended routing behavior, the policy document, the policy-version result, and post-policy route inspection. It can use this reference and the [constraint checklist](../SKILLS.md#3-constraint-checklist) to identify design and capability issues that are valid JSON but do not produce the intended routing behavior.

Then create a Cloud WAN policy version and review its change set:

```bash
aws networkmanager put-core-network-policy \
  --core-network-id <id> \
  --policy-document file://my-policy.json
```

Creating a policy version does not change the network until you execute its change set. Use the version result, the constraint checklist, and post-policy route inspection to diagnose unexpected behavior, such as an incorrect association, rule-order issue, unsupported attachment capability, or unintended route filter. You can perform these checks manually, but the agent-driven [validation workflow](../SKILLS.md#4-validate) is optimized to automate them.
