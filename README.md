> **Branch `public` — generated, do not commit here.** GitHub Actions builds it
> from `main` (commit `c9adca8`) for SAP S/4HANA Cloud Public Edition:
> the core only, without the on-premise adapter and wrapper. Changes go to `main`.

# Bill of Exchange Manager

> **Status: pre-release.** Phase 0 (validation) is in progress and the core is being
> built in slices. `src/` holds the first two - the posting contract
> `ZIF_BOE_POSTING`, the status rules and the adapter lookup, and the migration run
> with the upload of the migration file. Nothing here is ready to install in a
> customer system.

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

**One repository for every S/4HANA edition**, in two branches:

| Edition | Branch | Posting | Status |
|---|---|---|---|
| S/4HANA Cloud **Private Edition** and **on-premise** (2022+) | `main` — everything | adapter (`BOE_ONPREM`) calling a classic wrapper (`BOE_WRAP`) that posts with special G/L *W* | first — in development |
| S/4HANA Cloud **Public Edition** | `public` — generated from `main`, core only | released APIs only; the supported posting route is being validated (Phase 0) | planned |

All development happens on `main`. After every merge, GitHub Actions builds
`public`: the same objects without the on-premise adapter and wrapper, checked on
their own with the same gate (abaplint, language versions, off-stack tests).
Nobody commits to `public` by hand.

This works because the core is written for both editions from the start: ABAP
for Cloud Development, released APIs only, no reference to anything on-premise.
It finds the posting adapter of the system at runtime, through the adapter
registry (`ZTBOE_ADAPTER`), never by a static reference.

## Requirements

- **Private Edition / on-premise:** SAP S/4HANA **2022 or later** — `SAP_BASIS`
  757 and `S4CORE` 107; abapGit checks both before a pull. The minimum release is
  still being validated; if it moves to 2023, both numbers move with it
  (758 / 108). [abapGit](https://abapgit.org) in the system (standalone or
  developer version).
- **Public Edition:** a tenant with developer extensibility and the abapGit
  plugin of ADT (*abapGit Repositories* view). Branch `public` carries no
  release requirements and declares ABAP for Cloud Development for the whole
  repository.

## Package and parts

Everything is in **one package, `Z_BOE`** (`src/`, no sub-packages; the package
name is chosen when the repository is linked, so another name works too). Its
objects form three parts, told apart by the object name:

| Part | Object name contains | ABAP language version | In branch | Content |
|---|---|---|---|---|
| core | neither token below | ABAP for Cloud Development | `main`, `public` | RAP business objects, migration workbench, `ZIF_BOE_POSTING`, adapter registry |
| adapter | `BOE_ONPREM` — e.g. `ZCL_BOE_ONPREM_POSTING` | ABAP for Cloud Development | `main` | Private Edition / on-premise posting adapter: implements `ZIF_BOE_POSTING` by calling the wrapper |
| wrapper | `BOE_WRAP` — e.g. `ZCL_BOE_WRAP_POSTING`, function group `ZBOE_WRAP` | Standard ABAP | `main` | classic wrapper around the posting, released (contract C1) for use in ABAP Cloud |

**The core never references the adapter or the wrapper**, and no core object name
contains either token: that is what lets `public` be built by leaving the two
tokens out. The [checks](#checks) enforce both.

The package mixes language versions: its default is *ABAP for Cloud Development*,
and the wrapper objects are set to *Standard ABAP* one by one. On `main` the
abapGit repository setting *ABAP Language Version* stays empty, so every object
keeps its own.

## Installation

**Private Edition / on-premise** — branch `main`:

1. Make sure the system can reach GitHub from abapGit (SSL certificates for
   `github.com` in `STRUST`, and a personal access token while the repository is
   private).
2. Create the package `Z_BOE` (transportable).
3. In abapGit: **New Online** → this repository's URL, branch `main` → package
   `Z_BOE` → **Pull**.
4. Check that the wrapper objects (`*BOE_WRAP*`) are released for use in ABAP
   Cloud (API state, contract C1). If your abapGit version did not carry the
   release state, set it in ADT; otherwise the adapter does not activate.
5. Register the posting adapter in the adapter registry (`ZTBOE_ADAPTER`); until
   then the core posts nothing.

Where the customer does not allow abapGit, pull into one system (for example a
sandbox) and move the package with an ordinary transport.

The service binding `ZUI_BOEMIGRATIONRUN_O4` needs care on such a system:

- abapGit unpublishes a service binding before it imports it. Once the binding
  exists, leave it out of a pull unless its file has changed - on the development
  system a pull over the published binding left it inactive and unpublished, and
  it had to be deleted and created again.
- In a client that records customizing changes, ADT refuses to publish or
  unpublish the binding ("in Customizing Client not allowed"). Publish the
  service group in transaction `/IWFND/V4_ADMIN` instead.

**Public Edition** — branch `public`:

1. In ADT, *abapGit Repositories* view → **Link** → this repository's URL,
   branch **`public`** → package `Z_BOE` in a software component of the
   tenant → **Pull**.
2. Register the Public Edition adapter in the adapter registry once it exists
   (planned).

The Public Edition path has not been tried on a tenant yet (Phase 0, Q6).

## Migration file

Cheques are migrated from one Excel file per run:
[`docs/boe_migration_template.xlsx`](docs/boe_migration_template.xlsx). Sheet
`Cheques` takes one row per cheque from row 2; row 1 holds the column names. A
column is found by its name, so the columns may stand in any order and optional
ones may be left out; the sheet and the column names must keep their names. Sheet
`Instructions` describes every column with an example. Company code and posting
date belong to the run and are entered in the application.

In the application the file is uploaded to a run and checked with **Check File**:
every row becomes a cheque of the run with status *Ready* or *Has errors*, and
what is wrong with a row is listed with it. Errors are corrected in the file,
which is then uploaded and checked again.

## Development

1. In an S/4HANA 2022 system, create `Z_BOE` with ABAP language version
   *ABAP for Cloud Development*. Develop at the minimum release: an object that
   uses a newer feature does not import into an older one.
2. Link the package to branch `main` in abapGit (developer version), push to a
   feature branch and open a pull request against `main`. Never push to
   `public`.
3. Before the pull request, run the checks locally:

       npm ci
       npm run check

Naming follows the `abap-llm-rulebook` baseline: namespace `Z`, domain token
`BOE` — tables `ZTBOE_<entity>`, domains and data elements `ZBOE_<name>`, message
class `ZBOE`, exception classes `ZCX_BOE_<purpose>`; type-coded names (`ZCL_`,
`ZIF_`, `ZR_`, `ZC_`, …) stay as they are. Every table field is typed with a data
element of this package (or `MANDT`, the name the client field always has): a field
typed with any other SAP data element does not transpile off-stack. On top of that,
adapter and wrapper objects carry their token (`BOE_ONPREM`, `BOE_WRAP`), and no
core object may contain either.

Core logic is written to be testable without the system: ABAP Unit tests with
test doubles for `ZIF_BOE_POSTING` and for every other dependency on SAP
standard, so that they also run off-stack.

## Checks

`npm run check` runs abaplint, the language version check, then the core's unit
tests off-stack. GitHub Actions runs the same on every pull request and every push
to `main`, and builds branch `public` after every merge.

| Script | What it does |
|---|---|
| `npm run lint` | abaplint with `abaplint.json` (the on-premise template of `abap-llm-rulebook`) on all of `src/`, at release 7.57, the minimum release of this repository. `forbidden_identifier` enforces the core boundary: a core object that names a `BOE_ONPREM` or `BOE_WRAP` object fails |
| `npm run language` | every object except the wrapper must be serialized as ABAP for Cloud Development (`<UNICODE>5` for classes and interfaces, `<ABAP_LANGUAGE_VERSION>5` for the rest): a core object set to Standard ABAP by mistake would not import into Public Edition. A domain, data element, table, CDS view, access control, behavior definition, service definition or service binding without the element (`<ABAP_LANGU_VERSION>` for the last three) fails too - that is how abapGit serializes Standard ABAP for them. Metadata extensions and message classes carry no language version in their file and are not covered |
| `npm test` | transpiles the core with the abaplint transpiler (`abap_transpile.json`, libraries from [open-abap](https://github.com/open-abap)) and runs its ABAP Unit tests on Node.js, with an in-memory SQLite database |

An empty `src/`, or a core without a test class, is skipped.

**Branch `public`** (`.github/workflows/public.yml`, `tools/build-public.mjs`):
copies `main` without the workflows and without every `*boe_onprem*` / `*boe_wrap*`
file, drops the abapGit release requirements, sets the repository language
version to ABAP for Cloud Development, runs `npm run check` on the result and
commits it to `public` only when it passes.

Two deviations from the plain setup, both forced by what the tools support:
`abap_transpile.json` also leaves out access controls (`*.dcls.*` — the transpiler
rejects the object type), job classes (`zcl_boe_*_job` — they implement SAP
interfaces that open-abap does not have), the views of the business objects
(`zr_*.ddls`, `zc_*.ddls` — the transpiler builds a database view per CDS view and
cannot build one with an association) and the text views of fixed values
(`zi_boe*text.ddls` — they select from a table function of SAP); abaplint still
checks all of them. And `unused_ddic` in `abaplint.json` skips
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
