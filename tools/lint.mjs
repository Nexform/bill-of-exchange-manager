// Runs one abaplint configuration per part of the package (see parts.mjs).
//
//   core     abaplint-core.json     ABAP Cloud, release 7.57; adapter and wrapper
//                                   files are excluded, so a reference to them
//                                   fails as "not found"
//   adapter  abaplint-adapter.json  ABAP Cloud, release 7.57; the rest of src/ is
//                                   loaded as a dependency
//   wrapper  abaplint-wrapper.json  Standard ABAP, release 7.57
//
// The core check keeps the core movable to its own repository (and importable in
// Public Edition) later. A part without files yet is skipped, because abaplint
// fails on an empty file list.
//
// Usage: node tools/lint.mjs [core|adapter|wrapper] [abaplint options, e.g. --fix]

import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { parts, sourceFiles, SOURCE } from "./parts.mjs";

const require = createRequire(import.meta.url);
const cli = join(dirname(require.resolve("@abaplint/cli/package.json")), "abaplint");

const args = process.argv.slice(2);
const only = args[0] !== undefined && !args[0].startsWith("-") ? args.shift() : undefined;
const selected = only === undefined ? parts : parts.filter((part) => part.name === only);
if (selected.length === 0) {
  console.error(`Unknown part "${only}". Use one of: ${parts.map((part) => part.name).join(", ")}`);
  process.exit(2);
}

const files = sourceFiles().filter((file) => file !== "package.devc.xml");
let failed = false;
for (const part of selected) {
  if (!files.some(part.matches)) {
    console.log(`abaplint ${part.name}: skipped, no ${part.name} objects in ${SOURCE}/ yet`);
    continue;
  }
  console.log(`abaplint ${part.name}: ${part.config}`);
  const run = spawnSync(process.execPath, [cli, part.config, ...args], { stdio: "inherit" });
  if (run.status !== 0) {
    failed = true;
  }
}
process.exit(failed ? 1 : 0);
