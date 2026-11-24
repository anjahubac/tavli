#!/usr/bin/env python3
"""Propose, apply and seed reviewed allergen groups for shared catalog foods.

Source: Regulation (EU) No 1169/2011, Annex II (the 14 allergen groups). The
classifier below is a rule table written against that annex; it is a PROPOSAL.
Nothing becomes `reviewed` until a human runs `apply --reviewer NAME` on the
proposals file they checked. Foods the rules cannot settle are written with
confidence `needs_review` and an empty code list and are never applied.

  propose WORKSHEET PROPOSALS   write proposals CSV (candidates only)
  apply   WORKSHEET PROPOSALS --reviewer NAME
                                copy approved proposals into the worksheet
  seed    WORKSHEET OUTPUT.sql  UPDATE migration for reviewed worksheet rows
  seed-legacy PROPOSALS OUTPUT.sql --reviewer NAME
                                UPDATE migration for decided reference foods
"""

from __future__ import annotations

import argparse
import csv
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_food_catalog_seed import NAMESPACE, sql  # noqa: E402

SOURCE = "Regulation (EU) No 1169/2011, Annex II"
GROUPS = {
    "gluten", "crustaceans", "eggs", "fish", "peanuts", "soy", "milk", "nuts",
    "celery", "mustard", "sesame", "sulphites", "lupin", "molluscs",
}
NONE_RULE = "none: raw single ingredient, no Annex II group"

# name -> (codes, rule, confidence, note). Names are worksheet candidate names.
CONTAINS: dict[str, tuple[str, str, str, str]] = {}


def _add(names: str, codes: str, rule: str, confidence: str = "auto", note: str = "") -> None:
    for name in names.split(","):
        CONTAINS[name.strip()] = (codes, rule, confidence, note)


_add("raž,raženo brašno,speltino brašno,ječmeno brašno,zrno pšenice,kuskus,bulgur,"
     "brašno t-400,brašno t-500", "gluten", "Annex II 1: cereals containing gluten")
_add("ovseno brašno", "gluten", "Annex II 1: oats",
     "needs_review", "Oats are listed in Annex II 1; pure gluten-free oats are a labelling claim, not the default.")
_add("heljdino brašno", "", "none: buckwheat is not a cereal of Annex II 1", "needs_review",
     "Buckwheat is not in Annex II, but milled flour is often cross-contaminated; confirm none.")
_add("ovčije mleko,kozje mleko,bivolje mleko,kefir,rikota,maskarpone,ementaler,gorgonzola,"
     "gauda,čedar,edamer,feta,halumi,skir,kozji sir,ovčiji sir,bivolji sir,provolone,grujer,"
     "mančego", "milk", "Annex II 7: milk and products thereof")
_add("pačje jaje,prepeličje jaje", "eggs", "Annex II 3: eggs and products thereof")
_add("smuđ,šaran,som,orada,brancin,grdobina,bakalar,haringa,inćun,papalina",
     "fish", "Annex II 4: fish and products thereof")
_add("rečni rak", "crustaceans", "Annex II 2: crustaceans and products thereof")
_add("dagnja,ostriga,jakobova kapica,hobotnica,sipa", "molluscs",
     "Annex II 14: molluscs and products thereof")
_add("bademovo brašno,makadamija,brazilski orah,pekan orah,pistać,indijski orah", "nuts",
     "Annex II 8: nuts (almond, macadamia, Brazil, pecan, pistachio, cashew)")
_add("ulje od kikirikija", "peanuts", "Annex II 5: peanuts and products thereof",
     "needs_review", "Refined peanut oil is not exempt, but confirm the intended product.")
_add("susamovo ulje", "sesame", "Annex II 11: sesame seeds and products thereof")
_add("seme slačice", "mustard", "Annex II 10: mustard and products thereof")
_add("vinsko sirće", "sulphites", "Annex II 12: sulphur dioxide and sulphites >10 mg/kg",
     "needs_review", "Wine vinegar usually has sulphites above the threshold; confirm.")
_add("pirinčano sirće,javorov sirup,zeleni biber,hranjivi kvasac", "",
     "none: no Annex II ingredient, but processed", "needs_review",
     "Processed product; sulphites or carriers possible depending on the product. Confirm.")
_add("sveža urma,sveža smokva", "", NONE_RULE)


def classify(name: str, category: str) -> tuple[str, str, str, str]:
    """Return (codes joined by |, rule, confidence, note); '' codes = none."""
    if name in CONTAINS:
        return CONTAINS[name]
    if category in {"voće i povrće", "meso i riba", "suvi proizvodi", "začini i sosovi"}:
        # No Annex II group is a property of the plain raw ingredient only.
        return "", NONE_RULE, "auto", ""
    return "", "no rule", "needs_review", "No rule covers this food."


def _read(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as source:
        return list(csv.DictReader(source))


def _write(path: Path, rows: list[dict[str, str]], fields: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as out:
        writer = csv.DictWriter(out, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


PROPOSAL_FIELDS = [
    "candidate_name", "category_hint", "proposed_codes", "confidence", "rule",
    "note", "decision",
]


def propose(worksheet: Path, proposals: Path) -> dict[str, int]:
    old = {r["candidate_name"]: r for r in _read(proposals)} if proposals.exists() else {}
    out = []
    for row in _read(worksheet):
        if row["origin"] != "candidate":
            continue
        name = row["candidate_name"].strip()
        if row["allergen_status"] == "reviewed":
            continue  # already reviewed by a person; never overwritten
        codes, rule, confidence, note = classify(name, row["category_hint"])
        if any(c not in GROUPS for c in filter(None, codes.split("|"))):
            raise ValueError(f"Unknown allergen code for {name!r}: {codes}")
        out.append({
            "candidate_name": name, "category_hint": row["category_hint"],
            "proposed_codes": codes, "confidence": confidence, "rule": rule,
            "note": note,
            "decision": old.get(name, {}).get("decision", ""),
        })
    _write(proposals, out, PROPOSAL_FIELDS)
    counts = {"auto": 0, "needs_review": 0}
    for r in out:
        counts[r["confidence"]] += 1
    return counts


def apply(worksheet: Path, proposals: Path, reviewer: str) -> int:
    """Apply proposals whose decision is `approved` (the proposed codes) or
    `codes:a|b` / `codes:none` (the reviewer's own codes)."""
    if not reviewer.strip():
        raise ValueError("A named reviewer is required")
    decisions = {r["candidate_name"]: r for r in _read(proposals)}
    rows = _read(worksheet)
    fields = list(rows[0].keys())
    applied = 0
    for row in rows:
        p = decisions.get(row["candidate_name"])
        if not p or row["origin"] != "candidate" or row["allergen_status"] == "reviewed":
            continue
        decision = p["decision"].strip()
        if decision == "approved":
            if p["confidence"] != "auto":
                raise ValueError(f"{p['candidate_name']!r} needs explicit codes, not approved")
            codes = p["proposed_codes"] or "none"
        elif decision.startswith("codes:"):
            codes = decision[len("codes:"):].strip() or "none"
        else:
            continue
        values = [] if codes == "none" else codes.split("|")
        if len(values) != len(set(values)) or any(c not in GROUPS for c in values):
            raise ValueError(f"Invalid codes for {p['candidate_name']!r}: {codes}")
        row.update(
            allergen_status="reviewed", allergen_codes=codes,
            allergen_source=f"{SOURCE}; {p['rule']}", allergen_reviewer=reviewer.strip(),
        )
        applied += 1
    _write(worksheet, rows, fields)
    return applied


def seed(worksheet: Path, output: Path) -> int:
    statements = [
        "-- Generated by scripts/food_allergens.py from reviewed worksheet rows.",
        "-- Only foods with a named allergen review are updated; the rest stay unknown.",
    ]
    count = 0
    for row in sorted(_read(worksheet), key=lambda r: r["candidate_name"]):
        if row["origin"] != "candidate" or row["allergen_status"] != "reviewed":
            continue
        codes = row["allergen_codes"]
        values = [] if codes == "none" else codes.split("|")
        if any(c not in GROUPS for c in values) or len(values) != len(set(values)):
            raise ValueError(f"Invalid codes for {row['candidate_name']!r}: {codes}")
        if not row["allergen_source"].strip() or not row["allergen_reviewer"].strip():
            raise ValueError(f"{row['candidate_name']!r} lacks source or reviewer")
        name = row["candidate_name"].strip()
        array = "array[" + ", ".join(sql(c) for c in values) + "]::text[]" if values else "'{}'::text[]"
        statements.append(
            "update public.foods set "
            f"allergen_codes = {array}, allergen_source = {sql(SOURCE)}, "
            f"allergen_source_ref = {sql(row['allergen_source'] + ' (reviewed by ' + row['allergen_reviewer'] + ')')}, "
            "allergen_reviewed_at = now() "
            f"where id = {sql(str(uuid.uuid5(NAMESPACE, name)))} and household_id is null;"
        )
        count += 1
    output.write_text("\n".join(statements) + "\n", encoding="utf-8")
    return count


def seed_legacy(proposals: Path, output: Path, reviewer: str) -> int:
    """UPDATE migration for reference foods from decided proposal rows.

    Reference rows carry no decisions in the worksheet, so the proposals file
    is the review record: `approved` (auto rows only) or `codes:...`.
    """
    if not reviewer.strip():
        raise ValueError("A named reviewer is required")
    statements = [
        "-- Generated by scripts/food_allergens.py seed-legacy from decided proposals.",
        "-- Undecided reference foods stay unknown.",
    ]
    count = 0
    for p in sorted(_read(proposals), key=lambda r: r["candidate_name"]):
        decision = p["decision"].strip()
        if decision == "approved":
            if p["confidence"] != "auto":
                raise ValueError(f"{p['candidate_name']!r} needs explicit codes, not approved")
            codes = p["proposed_codes"] or "none"
        elif decision.startswith("codes:"):
            codes = decision[len("codes:"):].strip() or "none"
        else:
            continue
        values = [] if codes == "none" else codes.split("|")
        if len(values) != len(set(values)) or any(c not in GROUPS for c in values):
            raise ValueError(f"Invalid codes for {p['candidate_name']!r}: {codes}")
        name = p["candidate_name"].strip()
        array = "array[" + ", ".join(sql(c) for c in values) + "]::text[]" if values else "'{}'::text[]"
        ref = f"{SOURCE}; {p['rule']} (reviewed by {reviewer.strip()})"
        statements.append(
            "update public.foods set "
            f"allergen_codes = {array}, allergen_source = {sql(SOURCE)}, "
            f"allergen_source_ref = {sql(ref)}, allergen_reviewed_at = now() "
            f"where id = {sql(str(uuid.uuid5(NAMESPACE, name)))} and household_id is null;"
        )
        count += 1
    output.write_text("\n".join(statements) + "\n", encoding="utf-8")
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("propose", "apply", "seed"):
        p = sub.add_parser(name)
        p.add_argument("worksheet", type=Path)
        p.add_argument("target", type=Path)
        if name == "apply":
            p.add_argument("--reviewer", required=True)
    legacy = sub.add_parser("seed-legacy")
    legacy.add_argument("proposals", type=Path)
    legacy.add_argument("target", type=Path)
    legacy.add_argument("--reviewer", required=True)
    args = parser.parse_args()
    if args.command == "seed-legacy":
        print(seed_legacy(args.proposals, args.target, args.reviewer), "foods in", args.target)
        return
    if args.command == "propose":
        print(propose(args.worksheet, args.target))
    elif args.command == "apply":
        print(apply(args.worksheet, args.target, args.reviewer), "rows applied")
    else:
        print(seed(args.worksheet, args.target), "foods in", args.target)


if __name__ == "__main__":
    main()
