#!/usr/bin/env python3
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
"""Pre-merge checks on the Cloud WAN policies this repository ships.

Scope is deliberately narrow: make sure what we publish is internally consistent and
structurally valid. It does NOT try to reimplement Cloud WAN's own validation, and it is not
a tool for users - anyone adapting a blueprint should deploy it and read the errors Cloud WAN
returns, which are authoritative.

Three checks:

  1. Drift    - each pattern's CloudFormation PolicyDocument matches its baseline.json.
  2. Validity - every full policy document (the infra/ baselines - the only complete,
                deployable policies this repository ships) has the required shape: known
                top-level keys, the mandatory core-network-configuration fields, and valid
                enum values where a wrong one would be accepted as a string.
  3. Snippets - every fenced ```json block in policy/*.md parses, so the documentation cannot
                drift into invalid JSON.

Usage:
    python3 .github/scripts/check_policies.py

Exits non-zero on the first category with failures. Requires PyYAML to read the templates.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]

# The policy version this repository standardises on.
POLICY_VERSION = "2025.11"

# Top-level keys a Cloud WAN policy document may contain. Unknown keys are reported as a
# warning rather than an error: AWS has added top-level arrays after launch
# (network-function-groups, routing-policies) and a new one must not fail this repository's CI.
KNOWN_TOP_LEVEL = {
    "version",
    "core-network-configuration",
    "segments",
    "network-function-groups",
    "segment-actions",
    "attachment-policies",
    "routing-policies",
    "attachment-routing-policy-rules",
}

# Enum values where an invalid entry is still a valid JSON string, so a typo would otherwise
# survive until deploy time.
ENUMS = {
    "segment-action": {"share", "send-to", "send-via", "create-route", "associate-routing-policy"},
    "service-insertion-mode": {"single-hop", "dual-hop"},
    "routing-policy-direction": {"inbound", "outbound"},
    "attachment-policy-action": {"tag", "constant"},
}


class CfnLoader(yaml.SafeLoader):
    """SafeLoader that tolerates CloudFormation short-form intrinsics.

    The PolicyDocument block itself is pure data, but the surrounding template uses !Sub and
    !Ref, which SafeLoader rejects. The values of those tags are irrelevant here.
    """


def _ignore_cfn_tag(loader, tag_suffix, node):  # noqa: ANN001, ARG001
    if isinstance(node, yaml.ScalarNode):
        return loader.construct_scalar(node)
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    return loader.construct_mapping(node)


CfnLoader.add_multi_constructor("!", _ignore_cfn_tag)


class Findings:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    def report(self, heading: str) -> bool:
        print(f"\n{heading}")
        if not self.errors and not self.warnings:
            print("  OK")
        for w in self.warnings:
            print(f"  WARN   {w}")
        for e in self.errors:
            print(f"  ERROR  {e}")
        return not self.errors


def patterns() -> list[Path]:
    return sorted(p for p in (REPO_ROOT / "infra").iterdir() if (p / "baseline.json").is_file())


def policy_from_template(template: Path) -> dict | None:
    """The PolicyDocument of the CoreNetwork resource in a CloudFormation template."""
    document = yaml.load(template.read_text(), Loader=CfnLoader)
    for resource in (document.get("Resources") or {}).values():
        if resource.get("Type") == "AWS::NetworkManager::CoreNetwork":
            return (resource.get("Properties") or {}).get("PolicyDocument")
    return None


def check_drift() -> bool:
    """Each baseline*.json matches the template of the same name.

    A pattern normally ships one policy, `baseline.json`, embedded in
    `cloudformation/core_network.yaml`. A pattern that has to apply more than one policy -
    because a policy cannot reference something that does not exist yet - ships one file per
    policy, paired by suffix: `baseline_prefix_list.json` <-> `core_network_prefix_list.yaml`.
    """
    f = Findings()
    for pattern in patterns():
        for policy_file in sorted(pattern.glob("baseline*.json")):
            suffix = policy_file.stem[len("baseline"):]
            template = pattern / "cloudformation" / f"core_network{suffix}.yaml"
            label = f"{pattern.name}: {template.name}"

            baseline = json.loads(policy_file.read_text())
            if not template.is_file():
                f.error(f"{pattern.name}: {policy_file.name} has no cloudformation/{template.name}")
                continue
            embedded = policy_from_template(template)
            if embedded is None:
                f.error(f"{label} has no CoreNetwork PolicyDocument")
            elif embedded != baseline:
                f.error(
                    f"{label} PolicyDocument does not match {policy_file.name}. "
                    f"{_describe_difference(baseline, embedded)}"
                )

    return f.report("1. CloudFormation templates match baseline.json")


def _describe_difference(expected: dict, actual: dict) -> str:
    """Name the top-level keys that differ, so the failure is actionable."""
    differing = sorted(k for k in set(expected) | set(actual) if expected.get(k) != actual.get(k))
    return f"Differs in: {', '.join(differing)}." if differing else "Difference is in key ordering only."


def check_document(policy: dict, label: str, f: Findings) -> None:
    unknown = sorted(set(policy) - KNOWN_TOP_LEVEL)
    if unknown:
        f.warn(f"{label}: unrecognised top-level key(s) {unknown} - new Cloud WAN feature, or a typo?")

    if policy.get("version") != POLICY_VERSION:
        f.warn(f"{label}: version is {policy.get('version')!r}; this repository standardises on {POLICY_VERSION!r}")

    config = policy.get("core-network-configuration")
    if not isinstance(config, dict):
        f.error(f"{label}: core-network-configuration is required")
        return
    if not config.get("asn-ranges"):
        f.error(f"{label}: core-network-configuration.asn-ranges is required")
    locations = [e.get("location") for e in config.get("edge-locations") or []]
    if not locations:
        f.error(f"{label}: core-network-configuration.edge-locations is required")

    if not policy.get("segments"):
        f.error(f"{label}: at least one segment is required")
    for segment in policy.get("segments") or []:
        if not segment.get("name"):
            f.error(f"{label}: a segment has no name")

    for action in policy.get("segment-actions") or []:
        name = action.get("action")
        if name not in ENUMS["segment-action"]:
            f.error(f"{label}: segment-action {name!r} is not one of {sorted(ENUMS['segment-action'])}")
        if name == "send-via" and action.get("mode") not in ENUMS["service-insertion-mode"]:
            f.error(
                f"{label}: send-via on {action.get('segment')!r} has mode {action.get('mode')!r}; "
                f"expected one of {sorted(ENUMS['service-insertion-mode'])}"
            )

    for ap in policy.get("attachment-policies") or []:
        if ap.get("rule-number") is None:
            f.error(f"{label}: an attachment-policy has no rule-number")
        # An attachment either associates to a segment, or joins a network function group -
        # never both, so exactly one of these two forms must be present.
        action = ap.get("action") or {}
        method = action.get("association-method")
        nfg = action.get("add-to-network-function-group")
        if nfg is None and method not in ENUMS["attachment-policy-action"]:
            f.error(
                f"{label}: attachment-policy {ap.get('rule-number')} action must set either "
                f"association-method (one of {sorted(ENUMS['attachment-policy-action'])}) or "
                f"add-to-network-function-group; got {action!r}"
            )
        if nfg is not None and method is not None:
            f.error(
                f"{label}: attachment-policy {ap.get('rule-number')} sets both association-method and "
                f"add-to-network-function-group. An attachment joins a segment or a network function "
                f"group, never both."
            )

    for rp in policy.get("routing-policies") or []:
        direction = rp.get("routing-policy-direction")
        if direction not in ENUMS["routing-policy-direction"]:
            f.error(
                f"{label}: routing policy {rp.get('routing-policy-name')!r} direction is {direction!r}; "
                f"expected one of {sorted(ENUMS['routing-policy-direction'])}"
            )


def check_validity() -> bool:
    f = Findings()
    targets = [b for p in patterns() for b in sorted(p.glob("baseline*.json"))]
    for path in targets:
        label = str(path.relative_to(REPO_ROOT))
        try:
            policy = json.loads(path.read_text())
        except json.JSONDecodeError as exc:
            f.error(f"{label}: not valid JSON: {exc}")
            continue
        check_document(policy, label, f)
    print(f"\n   ({len(targets)} policy document(s) checked)", end="")
    return f.report("2. Policy documents are structurally valid")


FENCE = re.compile(r"^```json\s*$")


def check_snippets() -> bool:
    f = Findings()
    total = 0
    for md in sorted((REPO_ROOT / "policy").glob("*.md")):
        lines = md.read_text().splitlines()
        i = 0
        while i < len(lines):
            if FENCE.match(lines[i]):
                start = i + 1
                j = start
                while j < len(lines) and not lines[j].startswith("```"):
                    j += 1
                total += 1
                block = "\n".join(lines[start:j])
                try:
                    json.loads(block)
                except json.JSONDecodeError as exc:
                    f.error(f"{md.relative_to(REPO_ROOT)}:{start + 1}: not valid JSON: {exc}")
                i = j + 1
            else:
                i += 1
    print(f"\n   ({total} inline snippet(s) checked)", end="")
    return f.report("3. Inline JSON snippets in policy/*.md parse")


def main() -> int:
    ok = all([check_drift(), check_validity(), check_snippets()])
    print("\nAll policy checks passed." if ok else "\nPolicy checks FAILED.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
