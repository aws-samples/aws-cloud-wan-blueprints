# AWS Cloud WAN Blueprints

Welcome to AWS Cloud WAN Blueprints!

This project contains a collection of AWS Cloud WAN patterns implemented in [AWS CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html) and [Terraform](https://developer.hashicorp.com/terraform) that demonstrate how to configure and deploy global networks using [AWS Cloud WAN](https://aws.amazon.com/cloud-wan/).

## Motivation

AWS Cloud WAN simplifies the configuration and management of global networks by providing a centralized, policy-driven approach to building multi-region connectivity. While Cloud WAN abstracts away much of the complexity of traditional AWS networking (such as manual Transit Gateway peering, static routing, or associations and propagations), understanding all the service's capabilities can be overwhelming, especially when designing production-grade architectures.

AWS customers have asked for practical examples and best practices that demonstrate how to leverage Cloud WAN's full potential. These blueprints provide real-world use cases with complete, tested implementations that teams can use for:

- **Proof of Concepts (PoCs)**: Quickly validate Cloud WAN capabilities in your environment.
- **Testing and learning**: Understand how different features work together through hands-on examples.
- **Starting point**: Use as a foundation for your production network configurations.
- **Best practices**: Learn recommended patterns for common networking scenarios.

With Cloud WAN Blueprints, customers can configure and deploy purpose-built global networks and start onboarding workloads in days, rather than spending weeks or months figuring out the optimal configuration.

## Consumption

AWS Cloud WAN Blueprints have been designed to be consumed in the following manners:

1. **Reference**: Users can refer to the patterns and snippets provided to help guide them to their desired solution. Users will typically view how the pattern or snippet is configured to achieve the desired end result and then replicate that in their environment.

2. **Copy & Paste**: Users can copy and paste the patterns and snippets into their own environment, using Cloud WAN Blueprints as the starting point for their implementation. Users can then adapt the initial pattern to customize it to their specific needs.

**AWS Cloud WAN Blueprints are not intended to be consumed as-is directly from this project**. The patterns provided only contain `variables` when certain information is required to deploy the pattern and generally use local variables. If you wish to deploy the patterns into a different AWS Region or with other changes, it is recommended that you make those modifications locally before applying the pattern.

Every `infra/` pattern deploys across two AWS Regions (`us-east-1` and `eu-west-1`) — Cloud WAN is a global service, and a single-Region example would hide the cross-Region behaviour that is the point of it.

## Structure

AWS Cloud WAN Blueprints separates two things: **deployable infrastructure** and **what a
network policy can express**. A Cloud WAN answer is a policy document, and what
differentiates most designs is that document rather than the infrastructure underneath it —
inspection does not care whether an attachment is a VPC or a VPN.

So there is no directory per use case. There is infrastructure, and there is policy.

### `infra/` — deployable infrastructure

Each pattern is defined by **which attachment types it creates**, and ships a working
baseline policy so it deploys and forwards traffic out of the box.

| Pattern | Adds | Attachment types | IaC |
|---------|------|------------------|-----|
| [1. Basic](./infra/1-basic/) | Spoke VPCs across two Regions | `vpc` | Terraform, CloudFormation |
| [2. Inspection](./infra/2-inspection/) | Inspection VPCs with AWS Network Firewall | `vpc` (spoke + inspection) | Terraform, CloudFormation |
| [3. Transit Gateway](./infra/3-transit_gateway/) | A Transit Gateway per Region, peered with Cloud WAN | `vpc`, `transit-gateway-route-table` | Terraform, CloudFormation |
| [4. Hybrid](./infra/4-hybrid/) | Site-to-Site VPN, Connect, Direct Connect gateway — each optional | `vpc`, `site-to-site-vpn`, `connect`, `direct-connect-gateway` | Terraform, CloudFormation<br/>(hybrid attachments and prefix lists are Terraform-only) |
| [5. Multi-account](./infra/5-multi_account/) | Global network, core network, AWS RAM share — **no workloads** | none (spoke accounts create them) | Terraform, CloudFormation |

### `policy/` — what you can express

Organised to mirror the policy document's own top-level arrays, so each page maps to a part
of the JSON you write.

| Page | Produces |
|------|----------|
| [Building a policy](./policy/policy_generator.md) | The authoring workflow: intake, assembly order, constraint checklist |
| [1. Core network configuration](./policy/1-core_network_configuration.md) | `core-network-configuration` |
| [2. Segments](./policy/2-segments.md) | `segments` |
| [3. Attachment policies](./policy/3-attachment_policies.md) | `attachment-policies` |
| [4. Segment sharing](./policy/4-segment_sharing.md) | `segment-actions` (`share`) |
| [5. Service insertion](./policy/5-service_insertion.md) | `network-function-groups`, `segment-actions` (`send-to`, `send-via`) |
| [6. Routing policies](./policy/6-routing_policies.md) | `routing-policies`, `attachment-routing-policy-rules` |

Then point any pattern at the policy you built:

```bash
cd infra/2-inspection/terraform
terraform apply -var policy_document=../../../my-policy.json
```

[`blueprint.yaml`](./blueprint.yaml) is the machine-readable catalog and the source of
truth for what exists. [`V2.md`](./V2.md) explains why the repository is shaped this way.

### Moved from v1

The previous layout had one directory per use case under `patterns/`. Those use cases are
all still here — as policy guidance and snippets rather than as directories:

| v1 path | Now |
|---------|-----|
| `patterns/1-simple_architecture` | [`infra/1-basic`](./infra/1-basic/) |
| `patterns/2-multi_account` | [`infra/5-multi_account`](./infra/5-multi_account/) |
| `patterns/3-traffic_inspection/1-centralized_outbound` | [`infra/2-inspection`](./infra/2-inspection/) + [`send-to`](./policy/5-service_insertion.md#send-to--egress-inspection-north-south) |
| `patterns/3-traffic_inspection/2-…region_without_inspection` | [`policy/5-service_insertion.md`](./policy/5-service_insertion.md#a-region-with-no-local-inspection-vpc) — edge overrides |
| `patterns/3-traffic_inspection/3-east_west_dualhop` | [`infra/2-inspection`](./infra/2-inspection/) + [`dual-hop`](./policy/5-service_insertion.md#dual-hop-versus-single-hop) |
| `patterns/3-traffic_inspection/4-east_west_singlehop` | [`policy/5-service_insertion.md`](./policy/5-service_insertion.md#the-inspection-matrix) — the inspection matrix |
| `patterns/3-traffic_inspection/5-…tgw…dualhop` | [`infra/3-transit_gateway`](./infra/3-transit_gateway/) + [adding inspection](./infra/README.md), a documented local change |
| `patterns/3-traffic_inspection/6-…tgw…singlehop` | [`infra/3-transit_gateway`](./infra/3-transit_gateway/) + [adding inspection](./infra/README.md), a documented local change |
| `patterns/4-routing_policies/1-filtering_vpc_secondary_cidr_blocks` | [`policy/6-routing_policies.md`](./policy/6-routing_policies.md#dropping-a-specific-prefix) |
| `patterns/4-routing_policies/2-filtering_ipv4_ipv6_only_segments` | [`policy/6-routing_policies.md`](./policy/6-routing_policies.md#protocol-specific-segments) |
| `patterns/4-routing_policies/3-inspection_after_filtering` | [`policy/examples/filter_then_inspect.json`](./policy/examples/filter_then_inspect.json) |
| `patterns/4-routing_policies/4-filtering_by_bgp_community` | [`policy/6-routing_policies.md`](./policy/6-routing_policies.md#bgp-communities) |
| `patterns/4-routing_policies/5-influencing_hybrid_path_between_cnes` | [`policy/6-routing_policies.md`](./policy/6-routing_policies.md#preferring-one-regions-hybrid-edge) |
| `patterns/4-routing_policies/6-influencing_dxgw_hybrid_path` | [`policy/6-routing_policies.md`](./policy/6-routing_policies.md#preferring-the-geographically-aligned-direct-connect-gateway) |
| `patterns/4-routing_policies/7-summarization` | [`policy/6-routing_policies.md`](./policy/6-routing_policies.md#route-summarization) + [`infra/4-hybrid`](./infra/4-hybrid/) prefix lists |
| `patterns/4-routing_policies/8-filtering_peered_tgw` | [`policy/6-routing_policies.md`](./policy/6-routing_policies.md#route-filtering) + [`infra/3-transit_gateway`](./infra/3-transit_gateway/) |

## Infrastructure as Code Considerations

AWS Cloud WAN Blueprints do not intend to teach users the recommended practices for Infrastructure as Code (IaC) tools nor does it offer guidance on how users should structure their IaC projects. The patterns provided are intended to show users how they can achieve a defined architecture or configuration in a way that they can quickly and easily get up and running to start interacting with that pattern. Therefore, there are a few considerations users should be aware of when using Cloud WAN Blueprints:

1. We recognize that most users will already have existing VPCs in separate IaC projects or stacks. However, the patterns provided come complete with VPCs to ensure stable, deployable examples that have been tested and validated.

2. Patterns are not intended to be consumed in-place in the same manner that one would consume a reusable module. Therefore, we do not provide extensive parameters and outputs to expose various levels of configuration for the examples. Users can modify the pattern locally after cloning to suit their requirements.

3. The patterns use local variables (Terraform) or parameters (CloudFormation) with sensible defaults. If you wish to deploy patterns into different regions or with other changes, modify these values before deploying.

4. For production deployments, we recommend separating your infrastructure into multiple projects or stacks (e.g., network infrastructure, workload VPCs, inspection resources) to follow IaC best practices and enable independent lifecycle management.

## AWS Cloud WAN Fundamentals

[AWS Cloud WAN](https://docs.aws.amazon.com/network-manager/latest/cloudwan/what-is-cloudwan.html) is a managed, intent-driven service for building and managing global networks across [AWS Regions](https://aws.amazon.com/about-aws/global-infrastructure/regions_az/) and on-premises environments.

### Key Advantages

| Capability | Description |
|------------|-------------|
| **Automated Dynamic Routing** | Cross-region e-BGP routing |
| **Centralized Management** | Policy-driven configuration |
| **Network Segmentation** | Global segments for traffic isolation and routing domains |
| **Advanced Routing** | Fine-grained control with routing policies, filtering, and BGP manipulation |

---

### Control Plane & Network Policy

| Aspect | Details |
|--------|---------|
| **Management Console** | AWS Network Manager |
| **Home Region** | Oregon (us-west-2) - [Learn more](https://docs.aws.amazon.com/network-manager/latest/cloudwan/what-is-cloudwan.html#cloudwan-home-region) |
| **Policy Format** | Declarative JSON document |
| **Policy Defines** | Segments, routing behavior, attachment mappings, access control |

The policy-driven approach automates network configuration while ensuring scalability and consistency across AWS Regions.

---

### Core Network Edge (CNE)

| Aspect | Details |
|--------|---------|
| **Function** | Regional router (similar to Transit Gateway) |
| **Availability** | High-available and resilient |
| **Deployment** | One per AWS Region where Cloud WAN operates |
| **Peering** | Automatic full-mesh between all CNEs |
| **Routing Protocol** | e-BGP for dynamic route exchange |

---

### Segments

Global route table (similar to Transit Gateway route table or VRF domain)

| Characteristic | Description |
|----------------|-------------|
| **Availability** | Present in every Region with a CNE |
| **Regional Scope** | Can be limited to specific Regions |
| **Attachment Requirement** | Only possible in Regions where segment exists |
| **Default Behavior** | Attachments auto-propagate prefixes; intra-segment traffic allowed |
| **Isolation** | Supports isolated and non-isolated attachments |
| **Common Segmentation Patterns** | By environment (dev, test, prod), Business Unit (Org A, Org B, Org C), or Geography (AMER, EMEA, APAC) |

---

### Routing Action: Segment Sharing

Exchange routes between segments (1:1 or 1:many) without inspection.

> **Note**: Non-transitive - requires explicit share action between segments.

### Routing Action: Service Insertion

Define inspection for intra-segment, inter-segment, and egress traffic.

| Component | Description |
|-----------|-------------|
| **Network Function Groups (NFGs)** | Container for inspection VPC attachments |
| **Scope** | Global construct, supports cross-region inspection |
| **Multiple NFGs** | Supported for firewall grouping |

Service Insertion Actions:

| Action | Use Case | Traffic Flow |
|--------|----------|--------------|
| `send-via` | East-west inspection | Intra-segment or inter-segment traffic |
| `send-to` | Egress inspection | North-south traffic (internet-bound) |

### Routing Action: Routing Policies

Fine-grained routing controls for advanced scenarios.

| Capability | Description | Supported Attachments |
|------------|-------------|----------------------|
| **Route Filtering** | Drop routes based on prefixes, prefix lists, or BGP communities | All attachment types |
| **Route Summarization** | Aggregate routes outbound | BGP-capable attachments |
| **Path Preferences** | Influence paths via BGP attributes (Local Pref, AS-PATH, MED) | BGP-capable attachments |
| **BGP Communities** | Transitively pass, match, and act on communities | Site-to-Site VPN, Connect |

> **BGP-capable attachments**: Site-to-Site VPN, Direct Connect, Connect, Transit Gateway peering, CNE-to-CNE

[See AWS documentation for considerations](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-routing-policies.html#cloudwan-routing-policies-considerations)

---

### Attachments

Connection between network resource and Core Network Edge (CNE)

| Attachment Type | Description | Notes |
|-----------------|-------------|-------|
| **VPC** | Connect VPC to Cloud WAN | Most common attachment type |
| **Site-to-Site VPN** | IPsec tunnel to on-premises | Supports BGP |
| **Direct Connect Gateway** | Dedicated connection to on-premises | Supports BGP |
| **Transit Gateway Route Table** | Integrate existing Transit Gateways | Enables migration path |
| **Connect** | SD-WAN integration (GRE or tunnel-less) | Requires underlay VPC attachment |

> **Important**: Each attachment can only be associated with one segment.

---

### Attachment Policies

Rules that govern how attachments are associated with segments or Network Function Groups (NFGs). Matching Attributes:

| Attribute Type | Description |
|----------------|-------------|
| **Tags** | Key-value pairs on attachments |
| **Attachment Type** | VPC, VPN, Direct Connect, etc. |
| **AWS Account ID** | Source account of attachment |
| **AWS Region** | Region where attachment exists |

> **Note**: Pending attachments cannot access the core network until approved.

## Prerequisites

Before using these blueprints, you should have:

- **AWS Networking Knowledge**: Understanding of VPCs, subnets, route tables, Transit Gateways, and Direct Connect.
- **General Networking Concepts**: Familiarity with IP addressing, routing, IPSec, GRE, BGP, VRFs, SD-WAN, and network security.
- **Infrastructure as Code**: Experience with AWS CloudFormation or Terraform.
- **AWS Account**: An AWS account with appropriate IAM permissions to create networking resources.

## Support & Feedback

AWS Cloud WAN Blueprints are maintained by AWS Solution Architects. This is not part of an AWS service and support is provided as best-effort by the Cloud WAN Blueprints community. To provide feedback, please use the [issues templates](https://github.com/aws-samples/aws-cloud-wan-blueprints/issues) provided. If you are interested in contributing to Cloud WAN Blueprints, see the [Contribution guide](CONTRIBUTING.md).

## FAQ

**Q: I want a use case that is not in `infra/`. Where is it?**

A: Most likely in [`policy/`](./policy/). `infra/` patterns are organised by which
attachment types they create, not by use case — a use case is a policy document, and the
same infrastructure serves many of them. Find the capability you need under `policy/`, take
the snippets, and apply the result to whichever `infra/` pattern has the attachment types
you need. See [`policy/policy_generator.md`](./policy/policy_generator.md) for the
authoring workflow.

**Q: Can I use these patterns in production?**

A: These patterns are **not ready** for production environments. They should be customized for your specific requirements. Update variables, CIDR blocks, and configurations before deploying to production. Always test in pre-production environments first.

**Q: What are the bandwidth and MTU limits for Cloud WAN?**

A: Each Core Network Edge (CNE) supports up to 100 Gbps throughput. For detailed quotas and limits, see the [AWS Cloud WAN quotas documentation](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html).

**Q: Do I need separate AWS accounts to use these patterns?**

A: No, patterns 1 to 4 deploy in a single AWS account. [`infra/5-multi_account`](./infra/5-multi_account/) demonstrates sharing one core network across accounts with AWS Resource Access Manager, and documents the cross-account limitations that follow.

**Q: Which IaC tool should I use?**

A: Both CloudFormation and Terraform are supported for most patterns. Choose based on your organization's preferences and existing tooling. Terraform patterns use the [AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) and [AWSCC](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs) providers, while CloudFormation patterns use native AWS resources.

## Repository documentation

| Document | Audience | Purpose |
|----------|----------|---------|
| [`README.md`](./README.md) | Humans | This overview: motivation, pattern catalog, Cloud WAN fundamentals |
| [`infra/`](./infra/) | Humans | Deployable infrastructure, organised by which attachment types it creates |
| [`policy/`](./policy/) | Humans + agents | What a Cloud WAN network policy can express, and how to build one |
| [`blueprint.yaml`](./blueprint.yaml) | Tooling | Machine-readable catalog — the source of truth for what exists |
| [`SKILLS.md`](./SKILLS.md) | AI agents | Cloud WAN service knowledge: building blocks, the policy model, constraints, and a design workflow. Drop it into your own agent's context |
| [`CONVENTIONS.md`](./CONVENTIONS.md) | Contributors | The contract every pattern follows: naming, layout, version pins, license headers, parity policy, CI lockstep |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | Contributors | How to contribute, and how to run the same static checks locally that CI runs |
| [`V2.md`](./V2.md) | Maintainers | The v2 design: why the pattern-per-use-case layout was replaced by separated `infra/` and `policy/` trees, and what was decided against |
| [`tools/`](./tools/) | Contributors | Policy validation and the CloudFormation policy generator |

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See [LICENSE](LICENSE).
