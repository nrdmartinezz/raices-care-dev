/**
 * Builds seed/frost_stations.sql from the NOAA 1991–2020 annual/seasonal
 * normals archive. The archive is public domain. It is not committed.
 *
 *   node scripts/build-frost-seed.mjs
 *
 * Expects the tar.gz at %TEMP%/noaa-normals.tar.gz, or pass a path.
 */
import { execFileSync } from "node:child_process";
import { createWriteStream, existsSync, mkdirSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const archive =
  process.argv[2] ?? path.join(tmpdir(), "noaa-normals.tar.gz");
const extractDir = path.join(tmpdir(), "noaa-normals-csv");
const outFile = path.join(root, "seed", "frost_stations.sql");
const source = "noaa-ncei-1991-2020-t32-fp50";

const NON_LEAP = Date.UTC(2023, 0, 1);

function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = "";
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          cell += '"';
          i += 1;
        } else {
          quoted = false;
        }
      } else {
        cell += ch;
      }
      continue;
    }
    if (ch === '"') {
      quoted = true;
    } else if (ch === ",") {
      row.push(cell);
      cell = "";
    } else if (ch === "\n") {
      row.push(cell);
      rows.push(row);
      row = [];
      cell = "";
    } else if (ch !== "\r") {
      cell += ch;
    }
  }
  if (cell.length > 0 || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}

function doy(monthDay) {
  const match = /^(\d{2})\/(\d{2})$/.exec(monthDay.trim());
  if (!match) return null;
  const month = Number(match[1]);
  const day = Number(match[2]);
  const date = new Date(Date.UTC(2023, month - 1, day));
  if (date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  return Math.round((date.getTime() - NON_LEAP) / 86_400_000) + 1;
}

function stationFromCsv(text) {
  const [header, data] = parseCsv(text);
  if (!header || !data) return null;
  const index = new Map(header.map((name, i) => [name, i]));
  const id = data[index.get("STATION")]?.trim();
  const latitude = Number(data[index.get("LATITUDE")]);
  const longitude = Number(data[index.get("LONGITUDE")]);
  const lastSpring = doy(data[index.get("ANN-TMIN-PRBLST-T32FP50")] ?? "");
  const firstFall = doy(data[index.get("ANN-TMIN-PRBFST-T32FP50")] ?? "");
  if (!id || !/^[\w.-]+$/.test(id)) return null;
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return null;
  if (lastSpring == null || firstFall == null) return null;
  return { id, latitude, longitude, lastSpring, firstFall };
}

if (!existsSync(archive)) {
  throw new Error(`Missing NOAA archive at ${archive}`);
}

rmSync(extractDir, { recursive: true, force: true });
mkdirSync(extractDir, { recursive: true });
execFileSync("tar", ["-xzf", archive, "-C", extractDir], { stdio: "inherit" });

const files = [];
function walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith(".csv")) files.push(full);
  }
}
walk(extractDir);

const stations = new Map();
for (const file of files) {
  const station = stationFromCsv(readFileSync(file, "utf8"));
  if (station) stations.set(station.id, station);
}

const rows = [...stations.values()].sort((a, b) => a.id.localeCompare(b.id));
const stream = createWriteStream(outFile);
stream.write(
  `-- NOAA NCEI U.S. Climate Normals 1991-2020, public domain.\n` +
    `-- 50th percentile of the 32°F last spring freeze (ANN-TMIN-PRBLST-T32FP50)\n` +
    `-- and first fall freeze (ANN-TMIN-PRBFST-T32FP50).\n` +
    `-- Day-of-year uses a non-leap calendar so the month and day stay put.\n` +
    `-- Stations without both dates are omitted.\n\n`,
);

const chunk = 80;
for (let i = 0; i < rows.length; i += chunk) {
  const values = rows.slice(i, i + chunk).map((station) => {
    const lat = station.latitude.toFixed(4);
    const lon = station.longitude.toFixed(4);
    return `('${station.id}', ${lat}, ${lon}, ${station.lastSpring}, ${station.firstFall}, '${source}')`;
  });
  stream.write(
    "INSERT INTO frost_stations (id, latitude, longitude, last_spring_doy, first_fall_doy, source) VALUES\n" +
      values.join(",\n") +
      ";\n",
  );
}

await new Promise((resolve, reject) => {
  stream.end(() => resolve());
  stream.on("error", reject);
});

rmSync(extractDir, { recursive: true, force: true });
console.log(`Wrote ${rows.length} stations to ${outFile}`);
