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
2. [Repository layout](#repository-layout)
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

## Repository layout

abapGit folder logic `PREFIX`, starting folder `/src/`:

| Folder | Package | ABAP language version | Content |
|---|---|---|---|
| `src/` | `Z_BOE_ONPREM` | — | root package, no objects of its own |
| `src/core/` | `Z_BOE_ONPREM_CORE` | ABAP for Cloud Development | the core: RAP business objects, migration workbench, `ZIF_BOE_POSTING` |
| `src/adapter/` | `Z_BOE_ONPREM_ADAPTER` | ABAP for Cloud Development | Private Edition / on-premise posting adapter: implements `ZIF_BOE_POSTING` by calling the wrapper |
| `src/wrapper/` | `Z_BOE_ONPREM_WRAPPER` | Standard ABAP | classic wrapper around the posting, released (contract C1) for use in ABAP Cloud |

**The core never references the adapter or the wrapper.** It finds the adapter at
runtime, without a static reference. This keeps the core free of anything that
exists only on-premise, so it can move to its own repository and run in Public
Edition. The core check below enforces it.

The repository mixes language versions, so the abapGit repository setting
*ABAP Language Version* stays empty: every object keeps its own.

## Installation

1. Make sure the system can reach GitHub from abapGit (SSL certificates for
   `github.com` in `STRUST`, and a personal access token while the repository is
   private).
2. Create the root package `Z_BOE_ONPREM` (transportable).
3. In abapGit: **New Online** → this repository's URL → package `Z_BOE_ONPREM` →
   **Pull**. abapGit creates the sub-packages from the repository.
4. Check that the wrapper objects in `Z_BOE_ONPREM_WRAPPER` are released for use in
   ABAP Cloud (API state, contract C1). If your abapGit version did not carry the
   release state, set it in ADT; otherwise the adapter does not activate.

Where the customer does not allow abapGit, pull into one system (for example a
sandbox) and move the packages with an ordinary transport.

## Development

1. In an S/4HANA 2022 system, create the packages of the
   [layout](#repository-layout) with the ABAP language version shown for each.
   Develop in the system at the minimum release: an object that uses a newer
   feature does not import into an older one.
2. Link the root package to this repository in abapGit (developer version) and
   push to a branch; open a pull request against `main`.
3. Before the pull request, run the checks locally:

       npm ci
       npm run lint

Naming follows the `abap-llm-rulebook` baseline: namespace `Z`, domain token
`BOE` — packages `Z_BOE_<SUB>`, tables `ZTBOE_<entity>`, message class `ZBOE`,
exception classes `ZCX_BOE_<purpose>`; type-coded names (`ZCL_`, `ZIF_`, `ZR_`,
`ZC_`, …) stay as they are.

## Checks

`npm run lint` runs abaplint once per package, each file under exactly one
configuration. The rules come from the `abap-llm-rulebook` templates; the release
is 7.57 everywhere, the minimum release of this repository.

| Script | Configuration | Checks |
|---|---|---|
| `npm run lint:core` | `abaplint-core.json` | `src/core/` as ABAP for Cloud Development on 7.57. Loads **only** the core: a reference to an adapter or wrapper object fails as *not found* |
| `npm run lint:adapter` | `abaplint-adapter.json` | `src/adapter/` as ABAP for Cloud Development on 7.57; core and wrapper are loaded as dependencies and not linted |
| `npm run lint:wrapper` | `abaplint-wrapper.json` | `src/wrapper/` as Standard ABAP on 7.57 (on-premise template) |

A package whose folder is still empty is skipped. GitHub Actions runs the same
script on every pull request and every push to `main`.

Unlike the rulebook's Cloud template, the two Cloud configurations report unknown
objects only in the own namespace: the S/4HANA released APIs the core uses
(`I_JournalEntryTP`, …) are in no public API dump, so SAP objects stay unchecked
off-stack. ATC in the system covers them.

## License

[MIT](LICENSE)
