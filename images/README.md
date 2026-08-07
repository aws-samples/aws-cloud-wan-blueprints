# Architecture diagrams

## Editable sources

| File | Tool |
|------|------|
| `patterns.drawio` | [diagrams.net](https://www.diagrams.net/) |
| `cloud_wan_inspection_architectures.pptx` | PowerPoint |

Export to PNG at the same filename when updating a diagram.

## Where each diagram is used

| Diagram | Used by | Regions shown |
|---------|---------|---------------|
| `patterns_simple_architecture.png` | [`infra/1-basic`](../infra/1-basic/) | 2 |
| `east_west_singlehop.png` | [`policy/5-service_insertion.md`](../policy/5-service_insertion.md) — the inspection matrix | 4 |
| `patterns_filtering_secondary_cidr_blocks.png` | [`policy/6-routing_policies.md`](../policy/6-routing_policies.md) — route filtering | 2 |
| `patterns_summarization.png` | [`policy/6-routing_policies.md`](../policy/6-routing_policies.md) — summarization | 2 |
| `patterns_influencing_dxgw_hybrid_path.png` | [`policy/6-routing_policies.md`](../policy/6-routing_policies.md) — path preferences | 2 |
| `patterns_filtering_bgp_community.png` | [`policy/6-routing_policies.md`](../policy/6-routing_policies.md) — BGP communities | 2 |
| `patterns_inspection_after_filtering.png` | [`policy/README.md`](../policy/README.md) — the `filter_then_inspect` example | 2 |

## Retained but not currently referenced

These were drawn for the v1 layout and show **three or four** Regions, while every
[`infra/`](../infra/) pattern deploys two. Placing them on a pattern README would misstate
what gets deployed, so they are kept as source material rather than referenced:

`centralizedOutbound.png` · `centralizedOutbound_regionWithoutInspection.png` ·
`east_west_dualhop.png` · `east_west_tgw_spokeVpcs_dualhop.png` ·
`east_west_tgw_spokeVpcs_singlehop.png` · `patterns_filtering_ipv4_ipv6_segments.png` ·
`patterns_filtering_peered_tgws.png` · `patterns_influencing_path_between_regions.png` ·
`patterns_multi_account.png`

Redrawing any of them for two Regions makes it usable — see the table above for where it
would slot in.
