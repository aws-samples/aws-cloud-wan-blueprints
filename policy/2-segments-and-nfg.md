# Segments and network function groups

A [**segment**](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html#cloudwan-segments-json-about) is a **routing domain that spans your whole network**: one route table that exists in every Region where you declared a Core Network Edge (CNE). Declare `production` once and it is present at every CNE, with cross-Region reachability inside it handled by the CNE mesh — no peerings, no static routes, nothing to keep in step.

Four properties shape everything else you write:

* **A segment is closed to other segments by default.** There is no "allow all": every relationship between segments is declared, either by [`segment sharing`](./4-segment_sharing.md) or by [`service insertion`](./5-service_insertion.md) rules.
* **A segment is open internally by default.** Attachments in the same segment reach each other unless you enable [`isolate-attachments`](#isolate-attachments), which you can do from the moment you create the segment.
* **An attachment belongs to exactly one segment**, or to one network function group.
* **Segments do not solve overlapping CIDRs.** This is IP routing, so addresses have to be unique.

The other place an attachment can land is a [**network function group**](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html#cloudwan-network-functions-json): a specialised segment for inspection VPCs. The difference that matters is routing — you do not manage it. AWS Cloud WAN does, from the [`service insertion`](./5-service_insertion.md) rules you write.

## `segments`

The [`segments`](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-policies-json.html#cloudwan-segments-json-about) array is required and needs at least one entry. Every field a segment accepts appears below:

```json
{
  "segments": [
    {
      "name": "production",
      "description": "Regulated production workloads",
      "edge-locations": ["us-east-1", "eu-west-1"],
      "isolate-attachments": false,
      "require-attachment-acceptance": true,
      "deny-filter": ["development"]
    },
    {
      "name": "development",
      "description": "Non-production workloads",
      "isolate-attachments": true,
      "require-attachment-acceptance": false
    },
    {
      "name": "shared",
      "description": "Shared services reached from both",
      "require-attachment-acceptance": false,
      "isolate-attachments": true,
      "allow-filter": ["production", "development"]
    }
  ]
}
```

As you can see, a segment can be shaped in several different ways. The table below summarises what each field does, and the subsections after it take them one at a time.

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `name` | The segment's name, and the only way anything refers to it | Yes | — |
| `description` | A free-text description | No | — |
| `edge-locations` | Narrows the segment to a subset of your Regions | No | Every CNE Region |
| `isolate-attachments` | Whether attachments in this segment reach each other | No | `false` |
| `require-attachment-acceptance` | Whether a new attachment must be approved before it joins | No | `true` |
| `deny-filter` | Segments whose routes this one refuses, even if shared | No | — |
| `allow-filter` | The only segments whose routes this one accepts | No | — |

### `name` and `description`

The name is the segment's identity and the **only** handle it has, because there is no ARN or ID for a segment. Valid characters are `a`–`z`, `A`–`Z`, and `0`–`9`. The description is free text with no effect on routing.

```json
{ "name": "production", "description": "Regulated production workloads, EU and US" }
```

Since the name is the handle, every `segment-actions` entry and every `attachment-policies` rule refers to the segment by it, and it is what the console shows for metrics and other references. Expect a rename to mean updating each of those in the same policy version, and re-associating attachments that matched on the old value.

A description earns its place where the name cannot carry the reasoning on its own — which axis the segment belongs to, or what boundary it is meant to enforce.

### `edge-locations`

By default a segment exists at every CNE. This narrows it to a subset of the [Regions you declared](./1-core_network_version_configuration.md#core-network-configuration):

```json
{
  "name": "emea-restricted",
  "require-attachment-acceptance": false,
  "edge-locations": ["eu-west-1"]
}
```

In the example above, the segment's route table now exists only at `eu-west-1`, so an attachment created at any other CNE has nothing to join, whatever its tags say. It is a guardrail on **where attachments can exist**, not a change to how the segment routes — which makes it the way to enforce a residency requirement rather than document one.

An [`attachment-policies`](./3-attachment_policies.md) rule matching on `region` enforces the same thing, but restates it in every rule that could associate the segment. Combining the two is tidiest: the segment carries the residency boundary, the rules carry intent.

### `isolate-attachments`

Whether attachments in the segment reach each other. Defaults to `false`:

```json
{ 
  "name": "shared", 
  "require-attachment-acceptance": false, 
  "isolate-attachments": true 
}
```

Configured as `true`, an attachment's only routes are those shared in from other segments, or static ones — attachments in the segment become invisible to one another. Two very different uses:

* **Hub-and-spoke inside one segment.** Attachments reach what the segment is shared *with*, but not each other — so workloads reach shared services while the shared services stay isolated from one another.
* **Inspecting traffic inside a segment.** [Isolation is required for service insertion between attachments in the same segment](./5-service_insertion.md): it removes the direct route that would otherwise bypass the service insertion rule.

There's one exception, and it makes isolation **asymmetric**. A Transit Gateway route table attachment keeps advertising into the segment whatever this setting says, so the other attachments still learn its routes. Isolation does hold in the other direction: the route table attachment learns nothing from those attachments. For isolation in both directions, split the Transit Gateway route table attachment and your other attachments across segments — and control routing between them with sharing or service insertion.

### `require-attachment-acceptance`

Whether a new attachment must be approved before it joins the segment. Defaults to **`true`**, so attachments wait for a decision unless you say otherwise. This does not decide *which* segment an attachment lands in — that is entirely [`attachment-policies`](./3-attachment_policies.md). All it adds is a manual gate in front of whatever those rules already matched.

```json
{ "name": "production", "require-attachment-acceptance": true }
```

A pending attachment cannot reach the core network, and in a shared core network that gate is doing real work: the attachment is created by another team, and so is the tag that decides its segment. Left at `false`, attachments are also added to or removed from the segment automatically as those tags change — so `true` is not only a gate on first association, but what stops a spoke account tagging its way into a sensitive segment, then or later.

> **Acceptance is a manual step in a network whose whole point is being automatic.** Before configuring attachment acceptance everywhere, consider fixing the problem a level down: use [service control policies](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html) in AWS Organizations to govern who may set the tags your attachment policies match on. Match on tags a spoke account cannot change and the mis-tagging risk largely disappears, leaving acceptance for the segments where a human decision is genuinely warranted.

### `deny-filter` and `allow-filter`

Two guardrails on how routes exchange between segments, evaluated **after** every [`share`](./4-segment_sharing.md) action.

Sharing is bidirectional — a share lets attachments in both segments reach each other — which is easy to reason about while a policy is small. Real ones grow long and may be edited by several people, so eventually a `share` lands where it should not and two segments that were never meant to talk can reach each other. These filters sit on the segment rather than in a share statement, so the boundary holds whatever gets added later.

* **`deny-filter`**: segments this one will never exchange routes with. A share naming them does nothing.
* **`allow-filter`**: the only segments this one may exchange routes with. A share naming anything else does nothing, and a listed segment still needs a share before routes flow.

```json
{
  "segments": [
    { "name": "payments", "deny-filter": ["development"] },
    { "name": "video-producer", "allow-filter": ["video-distributor"] }
  ]
}
```

In the example above, `payments` will never exchange routes with `development` however many share actions are configured, and `video-producer` will only ever exchange routes with `video-distributor` (still the share action is needed). **Use one or the other on a segment, never both**.

> **Treat the policy as code and you may not need these at all.** A document that only changes through review — pull request, diff, a CI check — catches a stray `share` before it deploys, which keeps the policy simpler than encoding the same boundary in two places. Reach for a filter where the boundary matters too much to depend on someone reading the diff.

## `network-function-groups`

The array is optional, and each entry takes three fields:

```json
{
  "network-function-groups": [
    { 
      "name": "inspectionVpcs", 
      "description": "Inspection VPCs", 
      "require-attachment-acceptance": false 
    }
  ]
}
```

| Item | What it sets | Required | Default |
|------|--------------|----------|---------|
| `name` | The group's name, and the only way anything refers to it | Yes | — |
| `description` | A free-text description | No | — |
| `require-attachment-acceptance` | Whether a new attachment must be approved before it joins | No | No |

They behave much as they do on a segment, with only one difference. The `name` is referenced in two places, each covered on its own page: [`attachment-policies`](./3-attachment_policies.md), which work a bit different for network function group association, and the [`service insertion`](./5-service_insertion.md) directives that send traffic through it.

> **Attaching an Inspection VPC is usually a one-time event**, far less dynamic than workload attachments joining and leaving. Even so, it is worth some extra care over the association: the attachment lands in the traffic path of every segment that sends to the group, so the routing it creates reaches well beyond itself.

## How to segment my network?

A core network has a fixed, [non-adjustable limit on segments](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-quotas.html); and the limit documented is the sum of segments and network function groups. The practical ceiling is lower than the documented one. Past roughly ten segments a policy gets hard to reason about, because each new one adds relationships to declare, review and remember — not just a row in an array.

So segment on boundaries you will actually police. Four axes come up:

| Axis | Example segments | Segment on it when |
|------|------------------|--------------------|
| **Security boundary** | `trusted`, `untrusted`, `regulated` | Traffic crossing it must be controlled or inspected |
| **Environment** | `production`, `development` | Lifecycle isolation is the primary control |
| **Business unit** | `orga`, `orgb`, `shared` | Teams or tenants must not reach each other by default |
| **Geography** | `amer`, `emea`, `apac` | Residency or regional autonomy drives the design |

**Start from the security boundary.** It gives you the fewest segments that still enforce something, and the other three are often better expressed elsewhere: environment and business unit usually already separate at the account or OU level, and geography has [`edge-locations`](#edge-locations) on a segment you already have. Add a second axis only where it is a boundary you will enforce, since combining them — `prod-emea` and the rest — multiplies the count fast.

Two tests worth applying. If two things would always be shared with exactly the same set of other segments, they belong in one segment. And if you are reaching for one segment per application, the control you want should be done using Application Networking solutions, not routing domains.
