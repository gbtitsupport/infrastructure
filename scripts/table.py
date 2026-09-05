
#!/usr/bin/env python3
"""
Turn a `terraform show -json <plan>` file into a beginner-friendly markdown
table grouped by AWS service, so it's easy to scan in a GitHub Actions job
summary or a PR comment.

Usage:
    python3 tf_plan_table.py <plan.json> "<title>"
"""
import json
import sys
from collections import defaultdict


def load_plan(path):
    with open(path) as f:
        return json.load(f)


def service_from_type(resource_type):
    # aws_s3_bucket -> s3, aws_iam_role -> iam, aws_eks_cluster -> eks
    parts = resource_type.split("_")
    if len(parts) >= 2:
        return parts[1]
    return resource_type


def classify(actions):
    if actions == ["no-op"]:
        return None
    if actions == ["create"]:
        return "create"
    if actions == ["delete"]:
        return "destroy"
    if actions in (["create", "delete"], ["delete", "create"]):
        return "replace"
    if actions == ["update"]:
        return "update"
    return "update"  # fallback for anything unusual


def build_table(plan):
    rows = defaultdict(lambda: {"create": 0, "update": 0, "destroy": 0, "replace": 0})

    for change in plan.get("resource_changes", []):
        if change.get("mode") == "data":
            continue
        action = classify(change["change"]["actions"])
        if action is None:
            continue
        rtype = change["type"]
        service = service_from_type(rtype)
        rows[(service, rtype)][action] += 1

    totals = {"create": 0, "update": 0, "destroy": 0, "replace": 0}
    lines = [
        "| Service | Resource Type | ➕ Create | 🔄 Update | 🔁 Replace | ➖ Destroy | Total |",
        "|---|---|---|---|---|---|---|",
    ]

    for (service, rtype), counts in sorted(rows.items()):
        row_total = sum(counts.values())
        for k in totals:
            totals[k] += counts[k]
        lines.append(
            f"| {service} | `{rtype}` | {counts['create'] or ''} | {counts['update'] or ''} "
            f"| {counts['replace'] or ''} | {counts['destroy'] or ''} | {row_total} |"
        )

    grand_total = sum(totals.values())
    lines.append(
        f"| **Total** | | **{totals['create']}** | **{totals['update']}** "
        f"| **{totals['replace']}** | **{totals['destroy']}** | **{grand_total}** |"
    )

    if grand_total == 0:
        summary = "No changes. Infrastructure matches the configuration."
    else:
        parts = []
        if totals["create"]:
            parts.append(f"{totals['create']} to add")
        if totals["update"]:
            parts.append(f"{totals['update']} to change")
        if totals["replace"]:
            parts.append(f"{totals['replace']} to replace")
        if totals["destroy"]:
            parts.append(f"{totals['destroy']} to destroy")
        summary = "Plan: " + ", ".join(parts) + "."

    return "\n".join(lines), summary, grand_total


def main():
    if len(sys.argv) < 2:
        print("Usage: tf_plan_table.py <plan.json> [title]", file=sys.stderr)
        sys.exit(1)

    plan_path = sys.argv[1]
    title = sys.argv[2] if len(sys.argv) > 2 else "Terraform Plan"

    plan = load_plan(plan_path)
    table, summary, _ = build_table(plan)

    print(f"## {title}\n")
    print(summary + "\n")
    print(table)


if __name__ == "__main__":
    main()