# Receipt QR research: verification versus fiscal-device requests

**Status:** Independent research; the spike is not accepted or complete.
**Source task:** D1-019 / FR-001 in [025](spec.md). The report does not
implement scanning, a network client, receipt parsing or catalog import.

## Evidence and limits

The Serbian Tax Administration describes verification of a fiscal receipt by
scanning its printed QR code or following an electronic verification link. Its
[verification regulation](https://www.purs.gov.rs/upload/media/2025/2/4/374468/Pravilnikonacinuprovereprijavljenihfiskalnihracuna.pdf)
and [FAQ](https://purs.gov.rs/eFiskalizacija/odgovori_najcesca_pitanja.html)
describe receipt verification and the information on a receipt. What a receipt
contains is not, by itself, proof that its verification response returns each
field in a machine-readable structure.

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
direct access to the TaxCore documentation in this environment encountered a
redirect loop or unavailable URL. The JSON and POS format details above were
examined in indexed copies; their current live versions need rechecking before
a product decision. No actual receipt or verification URL was requested.

## Previous synthetic matching experiment

An offline experiment on the separate `tavli-next` catalog implementation
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

- Agree the time box, permitted samples, retention and go/no-go criteria with
  the relevant reviewer, as required by Q1. Do not collect real receipts before
  that agreement and explicit permission.
- With appropriately consented samples and an accepted handling process,
  measure what can be extracted and confirmed across different retailers.
  Record only aggregate results; do not store URLs or receipt contents in the
  repository.
- Verify actual current official response documentation, rejected destinations,
  redirects and bounded processing with synthetic fixtures before a product
  implementation. Repeat catalog matching against the team implementation.

No T001/T003 checkbox or team decision is completed by this document.
