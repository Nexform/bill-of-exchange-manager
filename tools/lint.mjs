// Runs one abaplint configuration per part of the repository.
//
//   core     abaplint-core.json     ABAP Cloud, release 7.57, sees only src/core
//   adapter  abaplint-adapter.json  ABAP Cloud, release 7.57, sees core + wrapper
//   wrapper  abaplint-wrapper.json  Standard ABAP, release 7.57
//
// The core configuration loads nothing but src/core, so any reference from the
// core to an adapter or wrapper object fails as "not found": that is the check
// that keeps the core movable to its own repository (and importable in Public
// Edition) later.
//
// A part whose folder has no files yet is skipped, because abaplint fails on an
// empty file list.
//
// Usage: node tools/lint.mjs [core|adapter|wrapper] [abaplint options, e.g. --fix]

import { spawnSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";

const require = createRequire(import.meta.url);
const cli = join(dirname(require.resolve("@abaplint/cli/package.json")), "abaplint");

const parts = [
  { name: "core", config: "abaplint-core.json", folder: "src/core" },
  { name: "adapter", config: "abaplint-adapter.json", folder: "src/adapter" },
  { name: "wrapper", config: "abaplint-wrapper.json", folder: "src/wrapper" },
];

const args = process.argv.slice(2);
const only = args[0] !== undefined && !args[0].startsWith("-") ? args.shift() : undefined;
const selected = only === undefined ? parts : parts.filter((part) => part.name === only);
if (selected.length === 0) {
  console.error(`Unknown part "${only}". Use one of: ${parts.map((part) => part.name).join(", ")}`);
  process.exit(2);
}

const hasFiles = (folder) =>
  existsSync(folder) &&
  readdirSync(folder, { recursive: true, withFileTypes: true }).some((entry) => entry.isFile());

let failed = false;
for (const part of selected) {
  if (!hasFiles(part.folder)) {
    console.log(`abaplint ${part.name}: skipped, ${part.folder}/ has no files yet`);
    continue;
  }
  console.log(`abaplint ${part.name}: ${part.config}`);
  const run = spawnSync(process.execPath, [cli, part.config, ...args], { stdio: "inherit" });
  if (run.status !== 0) {
    failed = true;
  }
}
process.exit(failed ? 1 : 0);
