/**
 * Seeds a small development catalog into /species.
 *
 * Run it against the emulator:
 *
 *   firebase emulators:start --only firestore
 *   $env:TREFLE_API_TOKEN = "<your token>"
 *   $env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"
 *   npm --prefix functions run seed
 *
 * The token is read from the environment for the length of the run and is
 * never written to a file. Targeting the real project needs both application
 * default credentials and an explicit --allow-production flag, so a stray run
 * cannot create production data.
 *
 * Sampling note: Trefle's /plants listing is dominated by wild flora — the
 * first page is oaks, nettles, clovers and grasses. A random sample would be
 * useless to a plant-care app, so this walks a curated set of search terms
 * covering the categories Raíces supports.
 */

import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

import {
  CARE_RULES_VERSION,
  deriveCareProfile,
  mapTrefleToSource,
  mapTrefleToSpecies,
  toSpeciesId,
} from "../catalog/species_mapper";
import {
  TREFLE_ATTRIBUTION,
  TREFLE_RATE_LIMIT_PER_MINUTE,
  TrefleSummary,
  fetchTrefleSpecies,
  searchTrefleSpecies,
} from "../catalog/trefle";
import { DERIVED_CARE_PROFILE_ID, SCHEMA_VERSION } from "../schema";

/** How many species to end up with. */
const TARGET_COUNT = 200;

/** Stay under the free tier's 60 requests per minute with a little headroom. */
const REQUEST_SPACING_MS = Math.ceil(60_000 / TREFLE_RATE_LIMIT_PER_MINUTE) + 50;

/** Search terms spanning the seven categories the app cares about. */
const SEED_TERMS = [
  // Houseplants and foliage
  "monstera", "pothos", "philodendron", "sansevieria", "ficus", "dracaena",
  "calathea", "anthurium", "spathiphyllum", "zamioculcas", "begonia", "peperomia",
  "chlorophytum", "aglaonema", "syngonium", "maranta", "hoya", "tradescantia",
  // Succulents and cacti
  "echeveria", "sedum", "crassula", "aloe", "haworthia", "agave", "opuntia",
  "sempervivum", "kalanchoe", "euphorbia", "mammillaria", "schlumbergera",
  // Herbs
  "ocimum", "rosmarinus", "salvia", "thymus", "mentha", "origanum",
  "petroselinum", "coriandrum", "anethum", "lavandula", "melissa", "artemisia",
  // Vegetables
  "solanum", "capsicum", "cucumis", "cucurbita", "lactuca", "brassica",
  "daucus", "allium", "spinacia", "phaseolus", "pisum", "beta",
  // Fruiting trees and shrubs
  "citrus", "malus", "prunus", "ficus carica", "vitis", "olea", "punica",
  "persea", "mangifera", "musa", "rubus", "fragaria", "vaccinium", "diospyros",
  // Flowers and ornamentals
  "rosa", "tulipa", "narcissus", "helianthus", "dahlia", "hydrangea",
  "pelargonium", "petunia", "hibiscus", "jasminum", "camellia", "paeonia",
  // Ornamental, non-fruiting trees
  "acer", "betula", "magnolia", "cercis", "lagerstroemia", "ginkgo",
];

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

function requireToken(): string {
  const token = process.env.TREFLE_API_TOKEN;
  if (!token) {
    throw new Error(
      "TREFLE_API_TOKEN is not set. Export it for this shell session only.",
    );
  }
  return token;
}

function assertSafeTarget(): string {
  const emulator = process.env.FIRESTORE_EMULATOR_HOST;
  const allowProduction = process.argv.includes("--allow-production");

  if (emulator) {
    return `Firestore emulator at ${emulator}`;
  }
  if (allowProduction) {
    return "the live Firestore project";
  }
  throw new Error(
    "Refusing to run: set FIRESTORE_EMULATOR_HOST to seed the emulator, " +
      "or pass --allow-production to write to the real project.",
  );
}

async function collectCandidates(token: string): Promise<TrefleSummary[]> {
  const bySpeciesId = new Map<string, TrefleSummary>();

  for (const term of SEED_TERMS) {
    if (bySpeciesId.size >= TARGET_COUNT) {
      break;
    }

    let matches: TrefleSummary[] = [];
    try {
      matches = await searchTrefleSpecies(term, token);
    } catch (error) {
      console.warn(`  search "${term}" failed:`, (error as Error).message);
    }
    await sleep(REQUEST_SPACING_MS);

    // Accepted species only; synonyms and sub-ranks add noise, not coverage.
    const usable = matches.filter(
      (match) =>
        match.scientific_name &&
        (match.status === null || match.status === "accepted") &&
        (match.rank === null || match.rank === "species"),
    );

    // Take the best few per term so one prolific genus cannot fill the sample.
    for (const match of usable.slice(0, 4)) {
      const id = toSpeciesId(match.scientific_name);
      if (!bySpeciesId.has(id)) {
        bySpeciesId.set(id, match);
      }
      if (bySpeciesId.size >= TARGET_COUNT) {
        break;
      }
    }

    console.log(`  ${term}: ${bySpeciesId.size} collected`);
  }

  return Array.from(bySpeciesId.values());
}

async function main(): Promise<void> {
  const token = requireToken();
  const target = assertSafeTarget();

  if (getApps().length === 0) {
    initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? "raices-care" });
  }
  const db = getFirestore();

  console.log(`Seeding up to ${TARGET_COUNT} species into ${target}.`);
  console.log("Collecting candidates from the catalog...");
  const candidates = await collectCandidates(token);
  console.log(`Found ${candidates.length} distinct species.`);

  let written = 0;
  let skipped = 0;
  let sparse = 0;

  for (const candidate of candidates) {
    const speciesId = toSpeciesId(candidate.scientific_name);
    const speciesRef = db.doc(`species/${speciesId}`);

    const existing = await speciesRef.get();
    if (existing.exists && existing.data()?.careRulesVersion === CARE_RULES_VERSION) {
      skipped += 1;
      continue;
    }

    let detail;
    try {
      // The listing carries no growth data, so each record needs its own read.
      detail = await fetchTrefleSpecies(candidate.slug, token);
    } catch (error) {
      console.warn(`  ${speciesId}: detail fetch failed:`, (error as Error).message);
      await sleep(REQUEST_SPACING_MS);
      continue;
    }
    await sleep(REQUEST_SPACING_MS);

    if (!detail.growth?.soil_humidity && !detail.growth?.light) {
      // Common: most records are well under half filled in, so the derived
      // care profile will fall back to default cadences.
      sparse += 1;
    }

    const batch = db.batch();

    batch.set(
      speciesRef,
      {
        ...mapTrefleToSpecies(detail),
        careRulesVersion: CARE_RULES_VERSION,
        ...(existing.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
      },
      { merge: true },
    );

    batch.set(
      speciesRef.collection("sources").doc(TREFLE_ATTRIBUTION.provider),
      mapTrefleToSource(detail),
      { merge: true },
    );

    batch.set(
      speciesRef.collection("careProfiles").doc(DERIVED_CARE_PROFILE_ID),
      {
        ...deriveCareProfile(detail, TREFLE_ATTRIBUTION.provider),
        careRulesVersion: CARE_RULES_VERSION,
        updatedAt: FieldValue.serverTimestamp(),
        schemaVersion: SCHEMA_VERSION,
      },
      { merge: true },
    );

    await batch.commit();
    written += 1;
    console.log(`  [${written}/${candidates.length}] ${speciesId}`);
  }

  console.log("");
  console.log(`Done. Wrote ${written}, skipped ${skipped} already current.`);
  console.log(`${sparse} records had no usable growth data; defaults applied.`);
  console.log(`Remember to surface "${TREFLE_ATTRIBUTION.attributionText}" in the app.`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
