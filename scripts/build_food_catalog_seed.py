#!/usr/bin/env python3
"""Build the one-time shared food and attributed nutrition seed migration."""

from __future__ import annotations

import argparse
import csv
import math
import re
import unicodedata
import uuid
from pathlib import Path

NAMESPACE = uuid.UUID("6405924b-b579-4ad4-9ab9-1309ccf5b531")
REVIEW_SOURCE = (
    "Owner-confirmed manual identity/base-unit review via chat (2026-11-23); "
    "individual reviewer unspecified."
)
CONFLICTING_ALIASES = {"brašno t-400", "brašno t-500"}


def sql(value: str | None) -> str:
    if value is None or value == "":
        return "null"
    return "'" + value.replace("'", "''") + "'"


def slugify(name: str) -> str:
    normalized = unicodedata.normalize("NFKD", name)
    ascii_name = normalized.encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", ascii_name).strip("-")


def load_rows(worksheet: Path, nutrition_csv: Path) -> list[dict[str, str]]:
    with worksheet.open(newline="", encoding="utf-8-sig") as source:
        foods = list(csv.DictReader(source))
    with nutrition_csv.open(newline="", encoding="utf-8-sig") as source:
        nutrition = {r["candidate_name"]: r for r in csv.DictReader(source)}

    output = []
    for food in foods:
        # Legacy-reference rows are comparison material, not new identities.
        if food["origin"] != "candidate":
            continue
        name = food["candidate_name"].strip()
        if food["identity_status"] != "reviewed":
            raise ValueError(
                f"Food is not approved for seeding: {name!r} "
                f"(identity_status={food['identity_status']!r})"
            )
        required_review_evidence = [
            "identity_source",
            "identity_reviewer",
            "base_unit_basis",
            "base_unit_reviewer",
            "usda_basis",
        ]
        if food["usda_fdc_id"].strip():
            required_review_evidence.append("usda_reviewer")
        missing_review_evidence = [
            field
            for field in required_review_evidence
            if not food[field].strip()
        ]
        if missing_review_evidence:
            raise ValueError(
                f"Food is missing review evidence: {name!r} "
                f"({', '.join(missing_review_evidence)})"
            )
        slug = slugify(name)
        if not slug:
            raise ValueError(f"Food has empty slug: {name!r}")
        unit = {"g": "gram", "ml": "milliliter", "kom": "piece"}.get(
            food["proposed_base_unit"]
        )
        if unit is None:
            raise ValueError(f"Food has unsupported base unit: {name!r}")
        n = nutrition.get(name)
        if n is None:
            raise ValueError(f"Missing nutrition worksheet row: {name!r}")
        worksheet_fdc_id = food["usda_fdc_id"].strip()
        csv_fdc_id = n["usda_fdc_id"].strip()
        if worksheet_fdc_id != csv_fdc_id:
            raise ValueError(
                f"Nutrition FDC ID does not match reviewed worksheet: {name!r} "
                f"(worksheet={worksheet_fdc_id!r}, nutrition={csv_fdc_id!r})"
            )
        nutrient_keys = (
            "kcal_per_100g", "protein_grams_per_100g",
            "fat_grams_per_100g", "carbs_grams_per_100g",
        )
        nutrient_values: dict[str, str] = {}
        for key in nutrient_keys:
            raw = n[key].strip()
            if not raw:
                continue
            try:
                value = float(raw)
            except ValueError as error:
                raise ValueError(
                    f"Invalid nutrient value for {name!r} ({key}={raw!r})"
                ) from error
            if not math.isfinite(value) or value < 0:
                raise ValueError(
                    f"Invalid nutrient value for {name!r} ({key}={raw!r})"
                )
            nutrient_values[key] = repr(value)
        complete = (
            len(nutrient_values) == len(nutrient_keys)
            and bool(worksheet_fdc_id)
            and bool(food["usda_reviewer"].strip())
        )
        output.append({
            "id": str(uuid.uuid5(NAMESPACE, name)),
            "slug": slug,
            "name": name,
            "category": food["category_hint"],
            "base_unit": unit,
            "nutrition": {**n, **nutrient_values} if complete else None,
            "aliases": [
                alias.strip()
                for alias in food["legacy_aliases"].split("|")
                if alias.strip()
            ],
        })
    if len({row["slug"] for row in output}) != len(output):
        raise ValueError("Canonical food slugs are not unique")
    return output


def generate(worksheet: Path, nutrition_csv: Path, output: Path) -> tuple[int, int, int]:
    foods = load_rows(worksheet, nutrition_csv)
    aliases: dict[str, tuple[str, str]] = {}
    for food in foods:
        for alias in food["aliases"]:
            key = " ".join(alias.lower().split())
            if key in CONFLICTING_ALIASES:
                continue
            if key in aliases and aliases[key][1] != food["id"]:
                raise ValueError(
                    f"Ambiguous shared alias {alias!r}: {aliases[key][1]} / {food['id']}"
                )
            aliases.setdefault(key, (alias, food["id"]))

    statements = [
        "-- Generated by scripts/build_food_catalog_seed.py.",
        "-- Candidate identities and units are owner-confirmed; see worksheet review.",
        "-- USDA SR Legacy values are used only for owner-reviewed mappings.",
        "-- Two historical flour aliases are omitted because they are distinct foods.",
        "insert into public.foods (",
        "  id, household_id, slug, name, category, base_unit, source, reviewed_at,",
        "  kcal_per_100g, protein_grams_per_100g, fat_grams_per_100g,",
        "  carbs_grams_per_100g, nutrition_source, nutrition_source_version,",
        "  nutrition_source_ref, created_at, updated_at",
        ") values",
    ]
    rows = []
    for food in foods:
        n = food["nutrition"]
        nutrients = [
            n[key] if n else None
            for key in (
                "kcal_per_100g", "protein_grams_per_100g",
                "fat_grams_per_100g", "carbs_grams_per_100g",
            )
        ]
        provenance = [
            "USDA FoodData Central" if n else None,
            "SR Legacy 2018-04" if n else None,
            f"FDC {n['usda_fdc_id']}" if n else None,
        ]
        values = [
            sql(food["id"]), "null", sql(food["slug"]), sql(food["name"]),
            sql(food["category"]), sql(food["base_unit"]), sql(REVIEW_SOURCE),
            "now()", *(str(v) if v is not None else "null" for v in nutrients),
            *(sql(v) for v in provenance), "now()", "now()",
        ]
        rows.append("  (" + ", ".join(values) + ")")
    statements.extend(",\n".join(rows).splitlines())
    statements.append("on conflict (id) do nothing;")
    statements += [
        "",
        "insert into public.food_aliases (",
        "  id, food_id, household_id, alias, alias_normalized, created_at, updated_at",
        ") values",
    ]
    alias_rows = []
    for normalized, (alias, food_id) in sorted(aliases.items()):
        alias_rows.append(
            "  (" + ", ".join([
                sql(str(uuid.uuid5(NAMESPACE, f"alias:{normalized}"))),
                sql(food_id), "null", sql(alias), sql(normalized), "now()", "now()",
            ]) + ")"
        )
    statements.extend(",\n".join(alias_rows).splitlines())
    statements.append("on conflict (id) do nothing;")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(statements) + "\n", encoding="utf-8")
    return len(foods), sum(bool(row["nutrition"]) for row in foods), len(aliases)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("worksheet", type=Path)
    parser.add_argument("nutrition_csv", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    foods, mapped, aliases = generate(args.worksheet, args.nutrition_csv, args.output)
    print(f"Foods: {foods}; complete USDA references: {mapped}; aliases: {aliases}")


if __name__ == "__main__":
    main()
