# AWS Cloud WAN Blueprints

Welcome to AWS Cloud WAN Blueprints!

This project demonstrates how to design, configure, and deploy global networks using [AWS Cloud WAN](https://aws.amazon.com/cloud-wan/). In Cloud WAN, the **network policy** is where your design lives — a declarative document that defines segments, sharing, inspection, and routing behavior. The blueprints are therefore organised around that document: guidance and best practices for everything a policy can express, plus deployable infrastructure building blocks (implemented in both [AWS CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html) and [Terraform](https://developer.hashicorp.com/terraform)) to deploy and test the policies you build.

> [!TIP]
> **Building with an AI agent?** Drop [`SKILLS.md`](./SKILLS.md) into your agent's context (system/skill file, retrieved doc, or pasted reference). It teaches the agent how to reason about Cloud WAN and how to turn your requirements into a complete network policy, a matching infrastructure pattern, and a validation plan — grounded in this repository's conventions. See [Generating a policy from your requirements](#generating-a-policy-from-your-requirements) below.

## Motivation

AWS Cloud WAN simplifies the configuration and management of global networks by providing a centralized, policy-driven approach to building networks at scale in AWS. While Cloud WAN abstracts away much of the complexity of traditional AWS networking (such as manual Transit Gateway peering, static routing, or associations and propagations), understanding all the service's capabilities can be overwhelming, especially when designing production-grade architectures — and because the design lives in the network policy, most of that learning curve is about what the policy can express.

AWS customers have asked for practical examples and best practices that demonstrate how to leverage Cloud WAN's full potential. These blueprints provide tested infrastructure building blocks and composable policy guidance that teams can use for:

- **Proof of Concepts (PoCs)**: Quickly validate Cloud WAN capabilities in your environment.
- **Testing and learning**: Understand how different features work together through hands-on examples.
- **Policy design**: Compose the network policy that expresses your requirements — from the best-practice guidance and snippets in [`policy/`](./policy/), or generated with an AI agent through [`SKILLS.md`](./SKILLS.md).
- **Starting point**: Use as a foundation for your production network configurations.
- **Best practices**: Learn recommended patterns for common networking scenarios.

With Cloud WAN Blueprints, customers can configure and deploy purpose-built global networks and start onboarding workloads in days, rather than spending weeks or months figuring out the optimal configuration.

## Consumption

AWS Cloud WAN Blueprints have been designed to be consumed in the following manners:

1. **Reference**: Use the [`policy/`](./policy/) pages to understand what a network policy can express — each capability's behavior, best practices, and caveats — and the [`infra/`](./infra/) patterns to see how each attachment type is created and connected to a core network. Learn how a construct works here, then replicate it in your own environment.

2. **Compose your policy**: Assemble the policy that expresses your requirements from the `policy/` snippets — by hand, or by giving [`SKILLS.md`](./SKILLS.md) to an AI agent that assembles and checks it for you (see [Generating a policy from your requirements](#generating-a-policy-from-your-requirements)). This is where most of your design effort should go: two networks with identical infrastructure behave completely differently depending on their policies.

3. **Deploy and adapt**: Copy the `infra/` pattern whose attachment types match what you need to connect, point it at your policy, and adapt it locally — Regions, CIDRs, tags — to fit your environment.

**AWS Cloud WAN Blueprints are not intended to be consumed as-is directly from this project**. Baseline policies exist to make the infrastructure patterns deploy and forward traffic out of the box — they are teaching examples, not recommendations for your network. Likewise, the patterns generally use local variables and only expose `variables` where information is required to deploy; if you wish to deploy into different AWS Regions or with other changes, make those modifications locally before applying the pattern.

## Structure

A Cloud WAN design can combine routing domains, attachment types, segment sharing, inspection, route controls, Regions, and account boundaries — so the number of complete end-to-end architectures is effectively unbounded. A repository with one directory per architecture would always be incomplete, and hard to keep consistent as the service evolves. What *is* bounded is the set of **building blocks**, and what differentiates most designs is the **network policy** rather than the infrastructure underneath it. So the blueprints are organised as three composable layers:

| Layer | Contains | Organised by |
|-------|----------|--------------|
| [`infra/`](./infra/) | **Deployable infrastructure** patterns, each shipping CloudFormation and Terraform plus a working baseline policy | Which **attachment types** it creates, plus multi-Account and prefix list association |
| [`policy/`](./policy/) | **What a network policy can express**: capabilities, best practices, constraints, and composable snippets | The policy document's own top-level areas |
| [`SKILLS.md`](./SKILLS.md) | **Agent knowledge and workflow**: how to translate requirements into a complete policy and pick the infrastructure to test it | Knowledge first, then the generation procedure |

Your end-to-end architecture is the combination: build the policy that expresses your requirements, then deploy it on the `infra/` pattern whose attachment types match what you need to connect.

## Generating a policy from your requirements

The policy is where your design lives, and [`SKILLS.md`](./SKILLS.md) exists so an AI agent can build it with you. It is an instruction set, not a code generator: given your requirements, an agent that has it in context can gather missing inputs, map intent to Cloud WAN constructs, assemble the document in dependency order, check it against the constraint checklist, and recommend the `infra/` pattern to test it on.

The skill does not work alone — these blueprints are its knowledge base. The [`policy/`](./policy/) pages give the agent each capability's behavior, constraints, and reviewed snippets to compose from, and the [`infra/`](./infra/) patterns give it tested infrastructure to recommend — so its answers are grounded in this repository's reviewed content and the [AWS Cloud WAN documentation](https://docs.aws.amazon.com/network-manager/latest/cloudwan/what-is-cloudwan.html) rather than the agent's general knowledge alone. That grounding also keeps the guidance current: as capability pages and patterns are added, the agent picks them up by reading the repository.

**1. Give the agent the skill.** Attach [`SKILLS.md`](./SKILLS.md) to your agent's context. The skill points at this repository's public pages, so an agent that can browse fetches the [`policy/`](./policy/) pages and [`infra/`](./infra/) patterns it references on its own — no clone needed. Clone the repository when the agent cannot browse, or when you want it to inspect or deploy the infrastructure code locally. Ask it to follow the [Building a policy](./SKILLS.md#building-a-policy) procedure rather than generating isolated JSON fragments.

**2. Describe your requirements.** The more explicit you are, the fewer assumptions the agent makes. A starting prompt:

```text
Use the AWS Cloud WAN blueprint instructions in SKILLS.md to design a complete
network policy and recommend an infrastructure pattern for testing it.

Requirements:
- Core network edge Regions:
- Routing domains or application environments:
- Required and prohibited communication between routing domains:
- Required communication within each routing domain:
- Attachment types, owning accounts, and identifying tags:
- Internet egress or east-west inspection requirements:
- Static route, route-filtering, or path-preference requirements:
- Multi-account sharing requirements:
- Preferred IaC format: Terraform, CloudFormation, or both:

Ask me for any information you need to avoid unsafe assumptions. Return the
complete policy document, the selected infra/ pattern and why it is compatible,
any staged deployment steps, your assumptions, and a validation plan.
```

**3. Review the result.** The agent should return a complete policy — every referenced segment, network function group, and route-control object defined; attachment tags matching the selected infrastructure; and Region, prefix-list, and staged-policy prerequisites made explicit.

**4. Validate the policy against Cloud WAN console or APIs, not just locally.** Create a policy version and review the change set Cloud WAN generates before executing it — that is the authoritative, state-aware validation. See [Validating a policy](./policy/README.md#validating-a-policy).

**5. Deploy and test.** Point the recommended `infra/` pattern at the generated policy (see [Deploying a policy of your own](./infra/README.md#deploying-a-policy-of-your-own)) and verify the resulting routes and paths, not just attachment status.

If an agent-generated policy does not match the requirements you gave it, please [report it with the unexpected policy output issue template](https://github.com/aws-samples/aws-cloud-wan-blueprints/issues/new?template=unexpected_policy_output.md) so the skill can be improved.

## Infrastructure as Code Considerations

AWS Cloud WAN Blueprints do not intend to teach users the recommended practices for Infrastructure as Code (IaC) tools nor does it offer guidance on how users should structure their IaC projects. The patterns provided are intended to show users how they can achieve a defined architecture or configuration in a way that they can quickly and easily get up and running to start interacting with that pattern. Therefore, there are a few considerations users should be aware of when using the blueprints:

1. We recognize that most users will already have existing VPCs in separate IaC projects or stacks. However, the patterns provided come complete with VPCs to ensure stable, deployable examples that have been tested and validated.

2. Patterns are not intended to be consumed in-place in the same manner that one would consume a reusable module. Therefore, we do not provide extensive parameters and outputs to expose various levels of configuration for the examples. The patterns use local variables (Terraform) or parameters (CloudFormation) with sensible defaults; if you wish to deploy into different AWS Regions or with other changes, modify the pattern locally after cloning before deploying.

3. The network policy is deliberately decoupled from the infrastructure. Each pattern reads its policy from a separate document (`baseline.json`) rather than hardcoding it, and the Terraform implementations accept your own file via the `policy_document` variable — because the policy is where your design lives and changes far more often than the infrastructure underneath it. Keep that separation in your own IaC: manage the policy as its own artifact with its own review and release cycle.

4. For production deployments, we recommend separating your infrastructure into multiple projects or stacks (e.g., the core network and its policy, workload VPCs, inspection resources) to follow IaC best practices and enable independent lifecycle management.

## AWS Cloud WAN Fundamentals

[AWS Cloud WAN](https://docs.aws.amazon.com/network-manager/latest/cloudwan/what-is-cloudwan.html) is a managed, intent-driven service for building and managing global networks across [AWS Regions](https://aws.amazon.com/about-aws/global-infrastructure/regions_az/) and on-premises environments. You describe the network you want in a declarative **network policy** — a versioned JSON document — and Cloud WAN builds and maintains it.

These are the constructs the blueprints compose — deliberately just enough vocabulary to navigate this repository. The behaviour, best practices, and caveats of each live in the linked `policy/` pages:

| Concept | What it is |
|---------|------------|
| **Core network & edges (CNEs)** | The core network is the global network your policy configures. A CNE is its regional hub, deployed in each Region the policy declares, automatically peered in a full mesh with e-BGP. See [core network configuration](./policy/1-core_network_version_configuration.md). |
| **Segments** | Global routing domains (similar to VRFs, or global Transit Gateway route tables), typically split by environment, business unit, or geography. See [segments and network function groups](./policy/2-segments-and-nfg.md). |
| **Attachments** | The connection between a network resource and a CNE: VPC, Site-to-Site VPN, Direct Connect gateway, Connect, or Transit Gateway route table. Each attachment associates with exactly one segment or network function group. |
| **Attachment policies** | Rules that decide that association, matching on tags, attachment type, account, or Region. See [attachment policies](./policy/3-attachment_policies.md). |
| **Segment sharing** | Explicit, non-transitive route exchange between segments. See [segment sharing](./policy/4-segment_sharing.md). |
| **Service insertion** | Sends traffic through inspection: `send-to` for egress (north-south), `send-via` for east-west, using network function groups. See [service insertion](./policy/5-service_insertion.md). |
| **Routing policies** | Fine-grained route filtering, summarization, and path preference for advanced scenarios. See [routing policies](./policy/7-routing_policies.md) and [attachment routing-policy rules](./policy/9-attachment_routing_policy_rules.md). |

Cloud WAN's management plane lives in its home Region (`us-west-2`), and policy changes are staged as versioned change sets you review before executing. This table is not exhaustive — [`policy/README.md`](./policy/README.md) maps everything a policy can express, including static routes and edge-location associations — and for the authoritative detail of each construct, see the [AWS Cloud WAN documentation](https://docs.aws.amazon.com/network-manager/latest/cloudwan/what-is-cloudwan.html).

## Prerequisites

Before using these blueprints, you should have:

- **AWS Networking Knowledge**: Understanding of VPCs, subnets, route tables, Transit Gateways, and Direct Connect.
- **General Networking Concepts**: Familiarity with IP addressing, routing, IPSec, GRE, BGP, VRFs, SD-WAN, and network security.
- **Infrastructure as Code**: Experience with AWS CloudFormation or Terraform.
- **AWS Account**: An AWS account with appropriate IAM permissions to create networking resources.

> If you deploy infrastructure from these blueprints to build a PoC, you are creating real, billable AWS resources. Use a non-production account, check the **Cost** section of the [`infra/`](./infra/) pattern you deploy to see what you will be billed for, and run its cleanup steps when you are finished.

## Support & Feedback

AWS Cloud WAN Blueprints are maintained by AWS Solution Architects. This is not part of an AWS service and support is provided as best-effort by the Cloud WAN Blueprints community. To provide feedback, please use the issues templates provided in this repository. If you are interested in contributing to Cloud WAN Blueprints, see the [Contribution guide](CONTRIBUTING.md) and the conventions every pattern follows in [`CONVENTIONS.md`](CONVENTIONS.md).

## FAQ

**Q: I want a use case that is not in `infra/`. Where is it?**

A: In [`policy/`](./policy/) — a use case is a policy document, and the same infrastructure serves many of them. Build the policy from the capability pages, then deploy it on the `infra/` pattern with the attachment types you need.

The infrastructure patterns are building blocks, not finished answers: if your policy needs extra resources, adapt the closest pattern — that is expected. An AI agent with [`SKILLS.md`](./SKILLS.md) can help with both: assembling the policy and adapting the infrastructure to it (see [Generating a policy from your requirements](#generating-a-policy-from-your-requirements)).

**Q: Can I use these patterns in production?**

A: These patterns are **not ready** for production environments. They should be customized for your specific requirements. Update variables, CIDR blocks, and configurations before deploying to production. Always test in pre-production environments first.

**Q: Do I need an AI agent to use these blueprints?**

A: No. Every `infra/` pattern deploys with its baseline policy as-is, and the `policy/` pages are a reference you can read and apply yourself. The agent workflow in `SKILLS.md` automates assembling a complete policy from requirements, but you can follow the same steps by hand.

**Q: Do I need separate AWS accounts to use these patterns?**

A: No, most patterns deploy in a single AWS account. [`infra/5-multi_account`](./infra/5-multi_account/) demonstrates sharing one core network across accounts with AWS Resource Access Manager, and documents the cross-account limitations that follow.

**Q: Which IaC tool should I use?**

A: Both CloudFormation and Terraform are supported for every infrastructure pattern. Choose based on your organization's preferences and existing tooling. Terraform patterns use the [AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) and [AWSCC](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs) providers, while CloudFormation patterns use native AWS resources.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See [LICENSE](LICENSE).
