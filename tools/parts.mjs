// The repository is one abapGit package (Z_BOE_ONPREM). The parts are told apart
// by object name, the same patterns the abaplint configurations and
// abap_transpile.json use:
//
//   adapter  names containing BOE_ONPREM  ABAP for Cloud Development
//   wrapper  names containing BOE_WRAP    Standard ABAP
//   core     everything else              ABAP for Cloud Development

import { existsSync, readdirSync } from "node:fs";

export const SOURCE = "src";

export const parts = [
  { name: "core", config: "abaplint-core.json", matches: (file) => !/boe_(onprem|wrap)/i.test(file) },
  { name: "adapter", config: "abaplint-adapter.json", matches: (file) => /boe_onprem/i.test(file) },
  { name: "wrapper", config: "abaplint-wrapper.json", matches: (file) => /boe_wrap/i.test(file) },
];

export const sourceFiles = () =>
  existsSync(SOURCE)
    ? readdirSync(SOURCE, { withFileTypes: true }).filter((entry) => entry.isFile()).map((entry) => entry.name)
    : [];
