# Bill of Exchange Manager

> **Status: pre-release.** Phase 0 (validation) is in progress and the core is being
> built in slices. `src/` holds the first one - data elements, the posting contract
> `ZIF_BOE_POSTING`, the status rules and the adapter lookup. There is no application
> yet; nothing here is ready to install in a customer system.

A clean-core tool for **cheques and bills of exchange** (επιταγές, συναλλαγματικές)
in **SAP S/4HANA Cloud Public Edition, Private Edition and on-premise**, built for
the Greek market: a migration workbench that replaces manual or BDC-based cheque
migration (F-36 / FB01 with special G/L *W*) and a register for the cheque
lifecycle — portfolio, endorsement, deposit for collection or as collateral,
collection, dishonour.

Users work in one RAP / Fiori Elements application, the same in every edition.
Only the posting differs: it sits behind an interface (`ZIF_BOE_POSTING`) with
one adapter per edition.

# Table of contents
1. [Editions](#editions)
2. [Requirements](#requirements)
3. [Package and parts](#package-and-parts)
4. [Installation](#installation)
5. [Migration file](#migration-file)
6. [Development](#development)
7. [Checks](#checks)
8. [License](#license)

## Editions

| Edition | Delivery | Posting | Status |
|---|---|---|---|
| S/4HANA Cloud **Private Edition** and **on-premise** (2022+) | **this repository**, installed with abapGit | adapter (`BOE_ONPREM`) calling a classic wrapper (`BOE_WRAP`) that posts with special G/L *W* | first — in design |
| S/4HANA Cloud **Public Edition** | the core in its own repository, `bill-of-exchange-manager` (ABAP Cloud only), plus a Public Edition adapter | released APIs only; the supported posting route is being validated (Phase 0) | planned |

The core is written for both from the start: ABAP for Cloud Development, released
APIs only, no reference to anything on-premise. While the Private Edition
delivery is built, the core lives here; once Public Edition is confirmed, it
moves to `bill-of-exchange-manager` and this repository keeps the adapter and
the wrapper.

## Requirements

- SAP S/4HANA (Cloud, private edition, or on-premise) **2022 or later**:
  `SAP_BASIS` 757 and `S4CORE` 107 — abapGit checks both before a pull. The
  minimum release is still being validated; if it moves to 2023, both numbers
  move with it (758 / 108).
- [abapGit](https://abapgit.org) in the target system (standalone or developer
  version).

## Package and parts

Everything is in **one package, `Z_BOE_ONPREM`** (`src/`, no sub-packages). Its
objects form three parts, told apart by the object name:

| Part | Object name contains | ABAP language version | Content |
|---|---|---|---|
| core | neither token below | ABAP for Cloud Development | RAP business objects, migration workbench, `ZIF_BOE_POSTING` |
| adapter | `BOE_ONPREM` — e.g. `ZCL_BOE_ONPREM_POSTING` | ABAP for Cloud Development | Private Edition / on-premise posting adapter: implements `ZIF_BOE_POSTING` by calling the wrapper |
| wrapper | `BOE_WRAP` — e.g. `ZCL_BOE_WRAP_POSTING`, function group `ZBOE_WRAP` | Standard ABAP | classic wrapper around the posting, released (contract C1) for use in ABAP Cloud |

**The core never references the adapter or the wrapper.** It finds the adapter at
runtime, without a static reference. This keeps the core free of anything that
exists only on-premise, so it can later move to its own repository and run in
Public Edition (see [Editions](#editions)). The name tokens make that move mechanical — every object without
them belongs to the core — and the [checks](#checks) enforce the boundary.

The package mixes language versions: its default is *ABAP for Cloud Development*,
and the wrapper objects are set to *Standard ABAP* one by one. The abapGit
repository setting *ABAP Language Version* stays empty, so every object keeps its
own.

## Installation

1. Make sure the system can reach GitHub from abapGit (SSL certificates for
   `github.com` in `STRUST`, and a personal access token while the repository is
   private).
2. Create the package `Z_BOE_ONPREM` (transportable).
3. In abapGit: **New Online** → this repository's URL → package `Z_BOE_ONPREM` →
   **Pull**.
4. Check that the wrapper objects (`*BOE_WRAP*`) are released for use in ABAP
   Cloud (API state, contract C1). If your abapGit version did not carry the
   release state, set it in ADT; otherwise the adapter does not activate.

Where the customer does not allow abapGit, pull into one system (for example a
sandbox) and move the package with an ordinary transport.

## Migration file

Cheques are migrated from one Excel file per run:
[`docs/boe_migration_template.xlsx`](docs/boe_migration_template.xlsx). Sheet
`Cheques` takes one row per cheque from row 2; row 1 holds the column names and is
checked on upload, so neither it nor the order of the columns may change. Sheet
`Instructions` describes every column with an example. Company code and posting
date belong to the run and are entered in the application.

## Development

1. In an S/4HANA 2022 system, create `Z_BOE_ONPREM` with ABAP language version
   *ABAP for Cloud Development*. Develop at the minimum release: an object that
   uses a newer feature does not import into an older one.
2. Link the package to this repository in abapGit (developer version), push to a
   branch and open a pull request against `main`.
3. Before the pull request, run the checks locally:

       npm ci
       npm run check

Naming follows the `abap-llm-rulebook` baseline: namespace `Z`, domain token
`BOE` — tables `ZTBOE_<entity>`, domains and data elements `ZBOE_<name>`, message
class `ZBOE`, exception classes `ZCX_BOE_<purpose>`; type-coded names (`ZCL_`,
`ZIF_`, `ZR_`, `ZC_`, …) stay as they are. Every table field is typed with a data
element of this package (or `MANDT`, the name the client field always has): a field
typed with any other SAP data element does not transpile off-stack. On top of that, adapter and wrapper objects carry their token
(`BOE_ONPREM`, `BOE_WRAP`), and no core object may contain either.

Core logic is written to be testable without the system: ABAP Unit tests with
test doubles for `ZIF_BOE_POSTING` and for every other dependency on SAP
standard, so that they also run off-stack.

## Checks

`npm run check` runs abaplint, then the core's unit tests off-stack. GitHub
Actions runs the same on every pull request and every push to `main`.

| Script | What it does |
|---|---|
| `npm run lint` | abaplint with `abaplint.json` (the on-premise template of `abap-llm-rulebook`) on all of `src/`, at release 7.57, the minimum release of this repository. `forbidden_identifier` enforces the core boundary: a core object that names a `BOE_ONPREM` or `BOE_WRAP` object fails |
| `npm test` | transpiles the core with the abaplint transpiler (`abap_transpile.json`, libraries from [open-abap](https://github.com/open-abap)) and runs its ABAP Unit tests on Node.js, with an in-memory SQLite database |

An empty `src/`, or a core without a test class, is skipped.

Two deviations from the plain setup, both forced by what the tools support:
`abap_transpile.json` also leaves out access controls (`*.dcls.*` — the transpiler
rejects the object type) and job classes (`zcl_boe_*_job` — they implement SAP
interfaces that open-abap does not have), and `unused_ddic` in `abaplint.json` skips
the `ZTBOE_*` tables, because a table read only by a CDS view or named as draft
table of a behavior definition does not count as referenced.

**What the checks leave to the system.** abaplint reads every object as Standard
ABAP: the ABAP Cloud restrictions of the core and the adapter are enforced by the
syntax check in the system, which the code has passed before abapGit pushes it,
and the release state of the SAP objects they use by ATC. The adapter and the
wrapper post through SAP FI, and the behavior pools (`zbp_*`) need the RAP
runtime: their tests run only in the system. The boundary check sees static
references only; a lookup by name at runtime (`CREATE OBJECT … TYPE (name)`) is
not a reference and is how the core finds its adapter.

## License

[MIT](LICENSE)
