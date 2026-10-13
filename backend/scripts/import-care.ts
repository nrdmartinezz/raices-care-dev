/**
 * Validates the care CSVs and writes published rows into local D1.
 *
 *   node --experimental-strip-types scripts/import-care.ts
 *   node --experimental-strip-types scripts/import-care.ts --apply
 */
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildCareSql, bundleFromCsv, validateCareBundle } from "../src/catalog/care_import.ts";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const careDir = path.join(root, "seed", "care");

function read(name: string): string {
  return readFileSync(path.join(careDir, name), "utf8");
}

const parsed = bundleFromCsv({
  species: read("species.csv"),
  profiles: read("care_profiles.csv"),
  rules: read("care_rules.csv"),
  sources: read("data_sources.csv"),
});
const errors = [...parsed.errors, ...validateCareBundle(parsed.bundle)];
if (errors.length > 0) {
  for (const error of errors) {
    console.error(`${error.table} row ${error.row}: ${error.message}`);
  }
  process.exit(1);
}

const sql = buildCareSql(parsed.bundle);
const outFile = path.join(careDir, "generated.sql");
writeFileSync(outFile, sql);
console.log(`Wrote ${outFile}`);

if (process.argv.includes("--apply")) {
  execFileSync(
    "npx",
    ["wrangler", "d1", "execute", "raices-care-sql", "--local", `--file=${outFile}`],
    { cwd: root, stdio: "inherit" },
  );
}
