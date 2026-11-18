// Runs abaplint (abaplint.json) on src/. abaplint fails on an empty file list,
// so the step is skipped while src/ has no objects yet.
//
// Usage: node tools/lint.mjs [abaplint options, e.g. --fix]

import { spawnSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";

const require = createRequire(import.meta.url);
const cli = join(dirname(require.resolve("@abaplint/cli/package.json")), "abaplint");

const objects = existsSync("src") ? readdirSync("src").filter((file) => file !== "package.devc.xml") : [];
if (objects.length === 0) {
  console.log("abaplint: skipped, no objects in src/ yet");
  process.exit(0);
}
const run = spawnSync(process.execPath, [cli, "abaplint.json", ...process.argv.slice(2)], { stdio: "inherit" });
process.exit(run.status ?? 1);
