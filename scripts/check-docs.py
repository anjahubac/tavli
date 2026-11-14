#!/usr/bin/env python3
"""Check maintained Tavli documentation without network, secrets or dependencies.

Historical specs are not rewritten; their old links are an audit concern, not
this gate. Checks cover local inline/reference Markdown links (not anchors or
remote URLs), the delivery register and key project-policy invariants.
"""
from collections import Counter
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


def without_code(text):
    text = re.sub(r"(?ms)^\s*(```|~~~).*?^\s*\1[^\n]*$", "", text)
    return re.sub(r"`[^`\n]*`", "", text)


def local_links(text):
    text = without_code(text)
    targets = re.findall(r"\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)", text)
    targets += re.findall(r"(?m)^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)", text)
    for target in targets:
        target = target.strip("<>")
        parsed = urlsplit(target)
        if not parsed.scheme and not parsed.netloc and parsed.path:
            yield unquote(parsed.path)


def active_documents(root):
    paths = [root / name for name in ("AGENTS.md", "CLAUDE.md", "README.md",
             "specs/README.md", ".github/pull_request_template.md",
             ".specify/memory/constitution.md")]
    for folder in ("docs", ".specify/templates"):
        paths.extend((root / folder).rglob("*.md"))
    for folder in (root / "specs").glob("[0-9][0-9][0-9]-*"):
        number = int(folder.name[:3])
        if number >= 8 and number != 10:
            paths.extend(folder.rglob("*.md"))
    paths.append(root / "specs/010-plan-and-shopping/current-direction.md")
    paths.extend((root / ".claude/skills").glob("speckit-*/SKILL.md"))
    return sorted(set(paths))


def registry_errors(data):
    errors = []
    tasks = data.get("tasks", [])
    expected = {"Dev 1": 20, "Dev 2": 21, "Dev 3": 20, "Dev 4": 26}
    if len(tasks) != 87 or Counter(t.get("role") for t in tasks) != expected:
        errors.append("Registry must preserve 87 source rows and role counts 20/21/20/26")
    ids = [t.get("id") for t in tasks]
    if len(set(ids)) != len(ids):
        errors.append("Registry contains duplicate task IDs")
    if sorted(t.get("source_row", 0) for t in tasks) != list(range(1, 88)):
        errors.append("Source rows must cover 1..87 exactly once")
    if not re.fullmatch(r"[a-f0-9]{64}", data.get("source_sha256", "")):
        errors.append("Registry must record the source SHA-256")
    for t in tasks:
        if not all(t.get(k) for k in ("title", "role", "assignee", "feature_key", "status")):
            errors.append(f"Incomplete task: {t.get('id')}")
        role = t.get("role", "")
        if role not in expected or not re.fullmatch(r"D[1-4]-\d{3}", t.get("id", "")):
            errors.append(f"Invalid task identity: {t.get('id')}")
        elif t["id"][1] != role[-1]:
            errors.append(f"Task role/ID mismatch: {t['id']}")
        if t.get("phase") not in range(1, 7):
            errors.append(f"Invalid phase: {t.get('id')}")
    return errors



def feature_errors(root, data, features):
    errors = []
    by_key = {}
    graph = {}
    spec_numbers = {int(p.name[:3]): p for p in
                    (root / "specs").glob("[0-9][0-9][0-9]-*") if p.is_dir()}
    for feature in features:
        key, path = feature["key"], feature["spec"]
        if key in by_key:
            errors.append(f"Duplicate feature key: {key}")
        by_key[key] = path
        folder = root / Path(path).parent
        number = int(folder.name[:3])
        graph[number] = feature["dependencies"]
        for required in ("spec.md", "plan.md", "tasks.md", "checklists/readiness.md"):
            if not (folder / required).is_file():
                errors.append(f"Missing feature artifact: {folder.name}/{required}")
        for dependency in feature["dependencies"]:
            if dependency not in spec_numbers:
                errors.append(f"Unknown dependency {dependency} in {folder.name}")
        tasks_file = folder / "tasks.md"
        if tasks_file.exists():
            ids = re.findall(r"(?m)^- \[.[ ]?\] (T\d+)\b", tasks_file.read_text())
            if len(ids) != len(set(ids)):
                errors.append(f"Duplicate task IDs: {folder.name}")
    for task in data["tasks"]:
        path = task.get("spec", "")
        if not path or by_key.get(task["feature_key"]) != path:
            errors.append(f"Feature/spec mapping mismatch: {task['id']}")
            continue
        folder = (root / path).parent
        if not (root / path).exists() or not (folder / "tasks.md").exists():
            continue
        spec = (root / path).read_text()
        tasks = (folder / "tasks.md").read_text()
        if f"**{task.get('requirement')}**" not in spec or task["id"] not in spec:
            errors.append(f"Missing mapped requirement/source: {task['id']}")
        for field in ("test_task", "implementation_task"):
            identity = task.get(field, "")
            lines = [line for line in tasks.splitlines()
                     if re.match(r"^- \[.[ ]?\] " + re.escape(identity) + r"\b", line)]
            if not identity or len(lines) != 1 or task["id"] not in lines[0]:
                errors.append(f"Missing/wrong {field}: {task['id']}")
    visiting, visited = set(), set()

    def visit(number):
        if number in visiting:
            errors.append(f"Feature dependency cycle at {number:03}")
            return
        if number in visited:
            return
        visiting.add(number)
        for dependency in graph.get(number, []):
            visit(dependency)
        visiting.remove(number)
        visited.add(number)

    for number in graph:
        visit(number)
    return errors


def broken_links(root, path):
    errors = []
    for target in local_links(path.read_text(encoding="utf-8")):
        resolved = (root / target.lstrip("/") if target.startswith("/")
                    else path.parent / target).resolve()
        if not resolved.is_relative_to(root.resolve()) or not resolved.exists():
            errors.append(f"Broken local link: {path.relative_to(root)} -> {target}")
    return errors


def check(root):
    errors = []
    documents = active_documents(root)
    for path in documents:
        if not path.is_file():
            errors.append(f"Missing required document: {path.relative_to(root)}")
            continue
        errors.extend(broken_links(root, path))
    register = root / "docs/development/task-register.json"
    try:
        data = json.loads(register.read_text(encoding="utf-8"))
        errors.extend(registry_errors(data))
        features = json.loads((root / "docs/development/feature-spec-index.json").read_text())["features"]
        errors.extend(feature_errors(root, data, features))
        mapping = (root / "docs/development/source-task-map.md").read_text()
        mapped_ids = re.findall(r"(?m)^\| (D[1-4]-\d{3}) \|", mapping)
        if Counter(mapped_ids) != Counter(t["id"] for t in data["tasks"]):
            errors.append("Source task map must contain each source ID exactly once")

        backlog = (root / "specs/011-team-development/contracts/delivery-backlog.md").read_text()
        rows = re.findall(r"(?m)^\| (D[1-4]-\d{3}) \|", backlog)
        if Counter(rows) != Counter(t["id"] for t in data["tasks"]):
            errors.append("Markdown backlog must contain every registry task once")
        product = (root / "docs/product-plan.md").read_text()
        keys = set(re.findall(r"(?m)^\| ([A-Z][A-Z-]+)(?: \(\d+\))? \|", product))
        keys.update(("TEAM-SETUP", "WEBSITE"))
        for task in data["tasks"]:
            expected_row = (f"| {task['id']} | {task['phase']} | {task['title']} | "
                            f"{task['feature_key']} |")
            if expected_row not in backlog:
                errors.append(f"Backlog/registry content mismatch: {task['id']}")
            if task["feature_key"] not in keys:
                errors.append(f"Unknown feature key: {task['feature_key']}")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append(f"Cannot validate task register: {exc}")
    constitution = (root / ".specify/memory/constitution.md").read_text()
    if "**Version**: 3.0.0" not in constitution or "### X." not in constitution:
        errors.append("Update the checker alongside a deliberate constitution version change")
    tasks_template = (root / ".specify/templates/tasks-template.md").read_text()
    if "mandatory" not in tasks_template or "test-first" not in tasks_template:
        errors.append("Task template must preserve mandatory test-first policy")
    for path in (root / ".claude/skills").glob("speckit-*/SKILL.md"):
        if "## Tavli project policy" not in path.read_text():
            errors.append(f"Missing local project policy: {path.relative_to(root)}")
    for path in (root / "specs/010-plan-and-shopping").rglob("*.md"):
        if path.name != "current-direction.md" and "current direction overlay" not in path.read_text():
            errors.append(f"Missing active 010 direction notice: {path.relative_to(root)}")
    return documents, errors


def main():
    documents, errors = check(ROOT)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"Documentation checks passed: {len(documents)} active Markdown files; "
          "87 source tasks; local links, spec/task mappings, dependencies and policy consistent.")
    print("Not checked: remote URLs, anchors, historical spec links or runtime acceptance.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
