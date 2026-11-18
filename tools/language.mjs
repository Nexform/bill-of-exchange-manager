// Checks the ABAP language version that abapGit serialized for every object in
// src/: <UNICODE> of classes and interfaces, <ABAP_LANGUAGE_VERSION> or - for
// behavior definitions, service definitions and service bindings -
// <ABAP_LANGU_VERSION> of the other object types; 5 = ABAP for Cloud Development.
//
// Standard ABAP looks different in the two groups: a class or an interface says
// <UNICODE>X, every other object simply has no such element (abapGit does not
// write the initial value). For the object types known to carry the element -
// domains, data elements, tables, CDS views, access controls, behavior
// definitions, service definitions and bindings - a file without it is therefore
// Standard ABAP and a violation. Types that never carry it (DDLX, MSAG) cannot
// be checked here.
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
const SOURCE = /\.(clas|intf)\.xml$/i;
const MARKED = /\.(doma|dtel|tabl|ddls|dcls|bdef|srvd|srvb)\.xml$/i;
const expected = `expected ABAP for Cloud Development (${CLOUD})`;

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
    const versions = [...xml.matchAll(/<ABAP_LANGU(?:AGE)?_VERSION>([^<]*)<\/ABAP_LANGU(?:AGE)?_VERSION>/g)].map((match) => match[1]);
    const unicode = xml.match(/<UNICODE>([^<]*)<\/UNICODE>/)?.[1];
    if (SOURCE.test(file) && unicode !== CLOUD) {
      violations.push(`${file}: language version "${unicode ?? "none"}", ${expected}`);
    } else if (versions.some((version) => version !== CLOUD)) {
      violations.push(`${file}: language version "${versions.find((version) => version !== CLOUD)}", ${expected}`);
    } else if (MARKED.test(file) && versions.length === 0) {
      violations.push(`${file}: no language version, which is how Standard ABAP is serialized, ${expected}`);
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
