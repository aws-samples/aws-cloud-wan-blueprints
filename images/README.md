# Architecture diagrams

## Editable source

| File | Tool |
|------|------|
| `patterns.drawio` | [diagrams.net](https://www.diagrams.net/) |

Every PNG in this directory is exported from `patterns.drawio`. When updating a diagram, edit the drawio source and re-export to PNG at the same filename.

## Where each diagram is used

Each diagram is named after the [`infra/`](../infra/) pattern it illustrates and shows the two Regions the pattern deploys (`us-east-1`, `eu-west-1`). It is referenced from the pattern README, the generated Terraform README (via `.header.md`), and the CloudFormation README.

| Diagram | Pattern |
|---------|---------|
| `1-basic.png` | [`infra/1-basic`](../infra/1-basic/) |
| `2-inspection.png` | [`infra/2-inspection`](../infra/2-inspection/) |
| `3-transit_gateway.png` | [`infra/3-transit_gateway`](../infra/3-transit_gateway/) |
| `4-hybrid.png` | [`infra/4-hybrid`](../infra/4-hybrid/) |
| `5-multi_account.png` | [`infra/5-multi_account`](../infra/5-multi_account/) |

[`infra/6-prefix_list_association`](../infra/6-prefix_list_association/) intentionally has no diagram: it creates no attachments or workloads, so there is no topology to draw.
