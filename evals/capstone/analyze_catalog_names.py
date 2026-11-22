#!/usr/bin/env python3
"""Summarize the catalog-name measurement traces (stdlib only).

Usage: python3 evals/capstone/analyze_catalog_names.py [traces_dir]
Reads catalog-names-{before,before-2,after,after-2}.jsonl and prints totals
per run, the names that stopped missing and the names that started missing.
"""
import collections
import json
import pathlib
import sys

d = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "evals/capstone/traces")
LABELS = ["before", "before-2", "after", "after-2"]


def load(label):
    lines = (d / f"catalog-names-{label}.jsonl").read_text().splitlines()
    head, rows = json.loads(lines[0]), [json.loads(x) for x in lines[1:]]
    return head, rows


def norm(s):
    return s.strip().lower()


runs = {l: load(l) for l in LABELS}
print("| Run | Commit | Dishes answered | Ingredients | Matched | Rate |")
print("| --- | --- | --- | --- | --- | --- |")
for l in LABELS:
    h, rows = runs[l]
    ok = sum(1 for r in rows if "ingredients" in r)
    print(f"| {l} | `{h['commit'][:7]}` | {ok}/{h['dishes']} | {h['ingredients']} | {h['matched']} | {100*h['matched']/h['ingredients']:.1f}% |")


def stats(label):
    """name -> [times seen, times matched]"""
    s = collections.defaultdict(lambda: [0, 0])
    for r in runs[label][1]:
        for i in r.get("ingredients", []):
            e = s[norm(i["name"])]
            e[0] += 1
            e[1] += 1 if i["matched"] else 0
    return s


def miss(labels):
    out = collections.Counter()
    for l in labels:
        for n, (seen, hit) in stats(l).items():
            out[n] += seen - hit
    return out


b, a = miss(["before", "before-2"]), miss(["after", "after-2"])
fixed = sorted(((b[n] - a[n], n) for n in b if b[n] - a[n] > 0), reverse=True)
broke = sorted(((a[n] - b[n], n) for n in a if a[n] - b[n] > 0), reverse=True)
print("\nNames missing less often after (misses before - misses after, over 2 runs each):")
for k, n in fixed[:15]:
    print(f"- {n}: {b[n]} -> {a[n]}")
print("\nNames missing more often after:")
for k, n in broke[:12]:
    print(f"- {n}: {b[n]} -> {a[n]}")
print("\nStill missing after (both runs), top 12:")
for n, k in a.most_common(12):
    print(f"- {n}: {k}")
