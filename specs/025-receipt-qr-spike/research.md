# Receipt QR research: verification versus fiscal-device requests

**Status:** Independent research; the spike is not accepted or complete.
**Source task:** D1-019 / FR-001 in [025](spec.md). The report does not
implement scanning, a network client, receipt parsing or catalog import.

## Evidence and limits

The Serbian Tax Administration describes verification of a fiscal receipt by
scanning its printed QR code or following an electronic verification link. Its
[verification regulation](https://www.purs.gov.rs/upload/media/2025/2/4/374468/Pravilnikonacinuprovereprijavljenihfiskalnihracuna.pdf)
states that a successful check lets the buyer view invoice data and download an
electronic copy (Article 4). The [FAQ](https://purs.gov.rs/eFiskalizacija/odgovori_najcesca_pitanja.html)
confirms that verification requires an internet connection and can be repeated.
Neither source specifies a stable machine-readable item schema or guarantees
that a QR verification response exposes item rows, quantities, unit prices or
GTINs to a third-party client.

An indexed copy of the TaxCore [JSON verification documentation](https://tap.suf.purs.gov.rs/Help/Home/ExportToPdf?file=%D0%A1%D0%BA%D0%B5%D0%BD%D0%B8%D1%80%D0%B0%D1%9A%D0%B5-%D1%80%D0%B0%D1%87%D1%83%D0%BD%D0%B0-%D1%81%D0%B0-JSON-%D0%BE%D0%B4%D0%B3%D0%BE%D0%B2%D0%BE%D1%80%D0%BE%D0%BC&hash=377035109)
describes an HTTPS request to the verification URL with `Accept:
application/json`. Its example includes request/result metadata, a textual
`journal` and validity; it does not establish that a structured item list or
GTIN is always present. Actual response availability and variants have not
been measured. Do not infer a quantity, package unit, price or barcode from
the existence of a QR code alone.

The separate [POS-to-SDC protocol](https://tap.sandbox.suf.purs.gov.rs/help/Home/ExportToPdf?all=true&file=POS-to-SDC-Protocol&hash=1174511688)
describes the request sent by the seller's software to the fiscal device; its
item fields and optional GTIN must not be assumed to be the response received
by a customer's QR verification request.

On 2026-11-15, the Administration FAQ and regulation were accessible, but
direct access to the TaxCore JSON-verification document returned unavailable
through the research browser. The TaxCore [protocol documentation](https://tap.suf.purs.gov.rs/Help/Home/ExportToPdf?all=true&file=Protocols&hash=1830242343)
was searchable, but it describes seller fiscal-device protocols and explicitly
uses environment-specific API URLs; it does not establish the customer QR
response schema. The JSON and POS format details above were examined in
indexed copies only. No actual receipt or verification URL was requested.

## Dev 1 decision proposal for Q1 / FR-103

This is a concrete owner proposal for independent review, not a team-approved
decision:

| Question | Proposed answer |
| --- | --- |
| Time box | Two hours of desk research using published official documentation and synthetic fixtures only. |
| Permitted sources | Public Tax Administration/TaxCore documentation and explicitly synthetic data. No personal receipt, live verification URL, credential, or third-party receipt service. |
| Retention | Keep only public source links, synthetic fixtures, and aggregate findings in the repository. Do not retain real receipt URLs, images, journal text, or extracted personal data. |
| Go criterion | Proceed only if a current official source defines an accessible, supported item-level response and an endpoint/redirect policy that can be safely allow-listed, and a synthetic fixture proves name, quantity and amount extraction. |
| Current outcome | **No-go for app-controlled receipt fetching/import.** The public evidence supports user verification and a downloadable copy, but does not establish a stable third-party item-level response or safe endpoint contract. |
| Scope if reconsidered | A new, separately reviewed contract and security slice must define the allowed URL format/hosts, redirects, size/time limits, parsing, consent and deletion behavior before any network or scanner code. |

The outcome is intentionally limited to automated import. It does not claim
that receipt verification itself is unavailable, nor does it prevent a later
product decision based on a supported interface and explicitly permitted
samples. Dev 3's agreement to Q1 and the team's product go/no-go remain open;
this proposal does not satisfy independent review or mark T001 complete.

## Previous synthetic matching experiment

An offline experiment on a separate reference catalog implementation
based on `e181050` used only fictional names and the existing exact-alias
matcher. On 2026-11-15, it produced:

| Fictional text | Result |
| --- | --- |
| `Jaja` | exact alias for `f_jaje` |
| `Mleko` | exact alias for `f_mleko` |
| `Mleko 2.8% 1L` | unresolved; review needed |

The [experiment source](fixtures/receipt_catalog_spike.dart.txt) is included
for inspection. It depends on the catalog and CSV parser in that separate
checkout, which do not exist on this team `dev` baseline. From that checkout,
after its package configuration has been prepared, the experiment can be run
without a receipt or network call (replace the path with the team checkout):

```sh
dart --packages=.dart_tool/package_config.json /path/to/team-checkout/specs/025-receipt-qr-spike/fixtures/receipt_catalog_spike.dart.txt
```

These three names show exact-alias behavior only; they do not
measure real receipt coverage, parse a journal or validate quantity and price
extraction. After the team catalog exists, repeat the experiment against its
accepted implementation rather than assuming the separate matcher was adopted.

## Acceptance coverage assessment

| Scenario | Evidence in this spike | Result |
| --- | --- | --- |
| SC-001: unsupported or malicious QR is rejected without an arbitrary fetch | The team baseline has no receipt scanner or receipt-fetch path. The proposal is no-go for adding one, so there is no fetch behavior to exercise. This is not a substitute for a security test if the feature is reconsidered. | No runtime path; future implementation requires negative destination and redirect tests plus an allowed control. |
| SC-002: a permitted synthetic receipt shows mapped fields and review cases | The offline fixture proves only two exact catalog aliases and one ambiguous name. It has no receipt structure, quantities or prices. | Insufficient to claim receipt-field extraction; no supported response schema was verified. |
| Empty, error, offline, cancel, retry, repeat and ownership transitions | No scanner, network client or persisted receipt state exists in the baseline. | Not applicable to this no-go research slice; must be specified and tested before implementation. |

This assessment records the missing behavior rather than counting the
synthetic alias experiment as receipt-import acceptance evidence.

## Safety and preliminary recommendation

Defer live receipt import until the response format, permitted hosts and
redirects, timeout/size limits, retention/deletion policy and consent are
reviewed. A future parser should treat a scanned URL and returned text as
untrusted, reject unexpected destinations before fetching and never log
receipt URLs or journal contents. Catalog matches and derived quantities
should remain reviewable; an ambiguous name is not proof of identity.

This is a preliminary technical recommendation, not the team's go/no-go
decision. It does not show that real receipts can be parsed reliably or that
any hosted behavior, SSRF protection or privacy controls have been tested.

## Work still required

- Dev 3 must accept or revise the Q1 proposal before T001 can be checked off.
- If the reviewer/team wants to revisit the no-go, obtain documented permission
  and a handling contract before using non-synthetic samples. Record only
  aggregate results; do not store URLs or receipt contents in the repository.
- Any future implementation still needs current endpoint documentation,
  synthetic negative/allowed controls for destinations and redirects, bounded
  processing, and catalog matching against the accepted team implementation.

No T001/T002/T003 checkbox or team decision is completed by this document.
