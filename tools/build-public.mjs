// Builds the tree of branch `public` - the delivery for SAP S/4HANA Cloud
// Public Edition - from a checkout of main. Run by .github/workflows/public.yml.
//
//   node tools/build-public.mjs <main checkout> <target folder> [commit]
//
// The target gets everything of main except the workflows (.github) and:
//   - the on-premise objects: names containing BOE_ONPREM (adapter) or BOE_WRAP
//     (wrapper);
//   - the abapGit requirements: SAP_BASIS / S4CORE releases of the on-premise
//     line say nothing about a Public Edition system.
// .abapgit.xml declares ABAP for Cloud Development for the whole repository, and
// the README says that the branch is generated. The build fails when an object
// that stays is not ABAP for Cloud Development.

import { cpSync, existsSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { cloudViolations } from "./language.mjs";

const [source, target, commit = "local"] = process.argv.slice(2);
if (source === undefined || target === undefined) {
  console.error("Usage: node tools/build-public.mjs <main checkout> <target folder> [commit]");
  process.exit(2);
}

const notCopied = new Set([".git", ".github", "node_modules", "output"]);
rmSync(target, { recursive: true, force: true });
cpSync(source, target, {
  recursive: true,
  filter: (path) => !notCopied.has(relative(source, path).split(sep)[0]),
});

const objects = join(target, "src");
const onPremise = existsSync(objects) ? readdirSync(objects).filter((file) => /boe_(onprem|wrap)/i.test(file)) : [];
for (const file of onPremise) {
  rmSync(join(objects, file));
}
console.log(`public: ${onPremise.length} on-premise files left out`);

const settingsFile = join(target, ".abapgit.xml");
const settings = readFileSync(settingsFile, "utf8")
  .replace(/\n\s*<REQUIREMENTS>[\s\S]*?<\/REQUIREMENTS>/, "")
  .replace("  </DATA>", "   <ABAP_LANGUAGE_VERSION>cloudDevelopment</ABAP_LANGUAGE_VERSION>\n  </DATA>");
if (!settings.includes("<ABAP_LANGUAGE_VERSION>cloudDevelopment</ABAP_LANGUAGE_VERSION>")) {
  console.error("public: could not set the ABAP language version in .abapgit.xml");
  process.exit(1);
}
writeFileSync(settingsFile, settings);

const readmeFile = join(target, "README.md");
const banner = `> **Branch \`public\` — generated, do not commit here.** GitHub Actions builds it
> from \`main\` (commit \`${commit.slice(0, 7)}\`) for SAP S/4HANA Cloud Public Edition:
> the core only, without the on-premise adapter and wrapper. Changes go to \`main\`.

`;
writeFileSync(readmeFile, banner + readFileSync(readmeFile, "utf8"));

const violations = cloudViolations(target);
if (violations.length > 0) {
  console.error("public: objects that are not ABAP for Cloud Development cannot go to Public Edition");
  for (const violation of violations) {
    console.error(`  ${violation}`);
  }
  process.exit(1);
}
console.log(`public: tree ready in ${target}`);
