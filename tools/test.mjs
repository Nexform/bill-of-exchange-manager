// Off-stack ABAP Unit: transpiles src/ to JavaScript with the abaplint
// transpiler (abap_transpile.json) and runs the unit tests.
//
// Only the core runs off-stack. abap_transpile.json leaves out the adapter and
// the wrapper (they post through SAP FI and are tested in the system) and the
// behavior pools (zbp_*, they need the RAP runtime). Without a test class in the
// core yet, the step is skipped.

import { spawnSync } from "node:child_process";
import { rmSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { parts, sourceFiles } from "./parts.mjs";

const require = createRequire(import.meta.url);
const transpiler = join(dirname(require.resolve("@abaplint/transpiler-cli/package.json")), "abap_transpile");
const core = parts.find((part) => part.name === "core");

const testClasses = sourceFiles().filter((file) => file.endsWith(".clas.testclasses.abap") && core.matches(file) && !/^zbp_/i.test(file));
if (testClasses.length === 0) {
  console.log("unit tests: skipped, no test class in the core yet");
  process.exit(0);
}

const run = (command, args) => {
  const result = spawnSync(process.execPath, [command, ...args], { stdio: "inherit" });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
};

rmSync("output", { recursive: true, force: true });
run(transpiler, []);
run(join("output", "index.mjs"), []);
