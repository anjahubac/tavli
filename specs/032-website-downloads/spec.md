# Specification: Website release and platform download handoff

**ID**: 032-website-downloads | **Feature key**: WEBSITE
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 4 | **Proposed independent reviewer**: Dev 3

## Scope and source

Implements the WEBSITE portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Use real store links and app screenshots on the website**. Source D4-023; Dev 4; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Present real app screenshots, coherent use flow and approved Tavli logo/app icons consistently, including browser icon.
- **FR-102**: Support Android, iOS, macOS, Windows and Linux download entries; before real verified links exist show Uskoro, not fake install links or QR codes.
- **FR-103**: Generate platform QR only for the same verified real destination as its button; show accessible text fallback and device-appropriate badges.
- **FR-104**: Website may ship already-verified platforms before Windows; the dependency on 028 gates only its Windows download. Publishing is not implied by this spec.

## User scenarios and acceptance

- **US1 / SC-001**: Without store URLs, every platform entry says Uskoro and no QR points to a placeholder.
- **US2 / SC-002**: For an available platform, button and QR resolve to the same approved release URL; screenshots contain only synthetic data.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Static public release information only. Never expose keys, accounts or personal screenshot data. External publishing requires the separately authorized website workflow.

## Exact UI copy carried forward

“Preuzmi”, “Uskoro”, “Android”, “iOS”, “macOS”, “Windows”, “Linux”.
Download page (`site/preuzmi/`): “Preuzmi Tavli”, “Recepti, plan obroka i lista za kupovinu.”,
“Preuzmi za Android”, “Preuzmi za iOS (IPA)”, “Preuzmi za macOS”, “Preuzmi za Windows”, “Preuzmi za Linux”,
“Sve verzije i SHA-256 provera fajlova” and the per-platform install hints in that file.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [028](../028-windows-support/spec.md)

- **Q1** (Dev 4 with reviewer): Verify website repository/location, ownership, approved logo assets, real store/download URLs and publication authorization.

### Recorded decisions

- **2026-11-24, Dev 4 (team chat)**: ship installable packages for Windows,
  Linux and Android and link them from website buttons and a QR code.
- **2026-11-24, Dev 1**: packages are GitHub Release assets of this repository
  with fixed names (`tavli-android.apk`, `tavli-windows-x64.zip`,
  `tavli-linux-x64.tar.gz`, `SHA256SUMS.txt`) under `releases/latest/download/`,
  so buttons and QR never change between versions. The website location is
  `site/preuzmi/` on the existing `welcome` Worker. Release builds use the
  production Supabase URL and anon key from repository secrets. The Android APK
  stays debug-signed until a release keystore is provided, so a later APK signed
  with a different key cannot update an installed one in place.
- **2026-11-24, Dev 1**: until the team has an Apple Developer account, iOS is
  an unsigned `tavli-ios.ipa` that the user re-signs with their own Apple ID
  (AltStore, Sideloadly; with a free Apple ID it runs for 7 days). The page says
  so and shows no iOS QR, because the IPA cannot be installed from the phone's
  browser. TestFlight replaces it once the account exists.
- **2026-11-24, Dev 1**: until the team has a Developer ID, macOS is an ad-hoc
  signed, not notarized `tavli-macos.dmg`; Gatekeeper blocks the first launch
  and the page explains “Ipak otvori” in Privacy & Security.
- Store listings (Play, App Store, Mac App Store) are not part of this slice.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
