// Checks the ABAP language version that abapGit serialized for every object in
// src/: <UNICODE> of classes and interfaces, <ABAP_LANGUAGE_VERSION> of the
// other object types; 5 = ABAP for Cloud Development.
//
// Every object except the wrapper (names containing BOE_WRAP) must be ABAP for
// Cloud Development: the core because it also goes to S/4HANA Cloud Public
// Edition (branch public), the adapter because it is ABAP Cloud by design.
//
// Usage: node tools/language.mjs [repository folder, default .]

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const CLOUD = "5";

export function cloudViolations(repository) {
  const source = join(repository, "src");
  if (!existsSync(source)) {
    return [];
  }
  const violations = [];
  for (const file of readdirSync(source)) {
    if (!file.endsWith(".xml") || file === "package.devc.xml" || /boe_wrap/i.test(file)) {
      continue;
    }
    const xml = readFileSync(join(source, file), "utf8");
    const versions = [...xml.matchAll(/<ABAP_LANGUAGE_VERSION>([^<]*)<\/ABAP_LANGUAGE_VERSION>/g)].map((match) => match[1]);
    const unicode = xml.match(/<UNICODE>([^<]*)<\/UNICODE>/)?.[1];
    if (/\.(clas|intf)\.xml$/i.test(file) && unicode !== CLOUD) {
      violations.push(`${file}: language version "${unicode ?? "none"}", expected ABAP for Cloud Development (${CLOUD})`);
    } else if (versions.some((version) => version !== CLOUD)) {
      violations.push(`${file}: language version "${versions.find((version) => version !== CLOUD)}", expected ABAP for Cloud Development (${CLOUD})`);
    }
  }
  return violations;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const violations = cloudViolations(process.argv[2] ?? ".");
  if (violations.length > 0) {
    console.error("ABAP language versions: only the wrapper (BOE_WRAP) may be Standard ABAP");
    for (const violation of violations) {
      console.error(`  ${violation}`);
    }
    process.exit(1);
  }
  console.log("ABAP language versions: ok");
}
