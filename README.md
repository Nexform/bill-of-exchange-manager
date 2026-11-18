# Bill of Exchange Manager — Private Edition / on-premise

> **Status: pre-release.** Phase 0 (validation) and the first design of the core
> are in progress. There is no code in `src/` yet; nothing here is ready to install
> in a customer system.

A clean-core tool for **cheques and bills of exchange** (επιταγές, συναλλαγματικές)
in SAP S/4HANA, built for the Greek market: a migration workbench that replaces
BDC-based cheque migration (F-36 / FB01 with special G/L *W*) and a register for
the cheque lifecycle — portfolio, endorsement, deposit for collection or as
collateral, collection, dishonour.

Users work in one RAP / Fiori Elements application. The posting itself sits
behind an interface, so the same application can later run in S/4HANA Cloud
Public Edition with a different posting adapter.

This repository is the **Private Edition / on-premise** delivery. It is installed
with abapGit.

# Table of contents
1. [Requirements](#requirements)
2. [Package and parts](#package-and-parts)
3. [Installation](#installation)
4. [Development](#development)
5. [Checks](#checks)
6. [License](#license)

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
Public Edition. The name tokens make that move mechanical — every object without
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
`BOE` — tables `ZTBOE_<entity>`, message class `ZBOE`, exception classes
`ZCX_BOE_<purpose>`; type-coded names (`ZCL_`, `ZIF_`, `ZR_`, `ZC_`, …) stay as
they are. On top of that, adapter and wrapper objects carry their token
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
