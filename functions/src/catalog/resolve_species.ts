import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";

import { db, FieldValue } from "../admin";
import {
  DEFAULT_REGION,
  DERIVED_CARE_PROFILE_ID,
  SCHEMA_VERSION,
} from "../schema";
import {
  deriveCareProfile,
  mapTrefleToSource,
  mapTrefleToSpecies,
  toSpeciesId,
} from "./species_mapper";
import {
  TREFLE_API_TOKEN,
  TREFLE_ATTRIBUTION,
  TrefleError,
  TrefleSummary,
  fetchTrefleSpecies,
  searchTrefleSpecies,
  type SpeciesSearchFilters,
} from "./trefle";
import {
  fetchInaturalistScientificName,
  lookupGardenName,
  mergeBySlug,
  normalizeVernacular,
} from "./vernacular";

/** Re-fetch a cached species once its data is this old. */
const CACHE_TTL_DAYS = 90;

const SEARCH_RANKS = new Set([
  "species",
  "subspecies",
  "variety",
  "form",
  "hybrid",
  "subvariety",
]);

const SEARCH_FAMILIES = new Set([
  "Asteraceae",
  "Orchidaceae",
  "Fabaceae",
  "Rubiaceae",
  "Poaceae",
  "Lamiaceae",
  "Apocynaceae",
]);

function allowedList(value: unknown, allowed: Set<string>): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter(
    (item): item is string => typeof item === "string" && allowed.has(item),
  );
}

/**
 * App Check stays advisory until the app has been exercised on real devices
 * with Play Integrity and App Attest registered. Flip both of these to true
 * together, after verifying debug builds still work.
 */
const ENFORCE_APP_CHECK = false;

/**
 * Callables are reached from the app with a Firebase ID token, which the
 * functions framework verifies itself, so Cloud Run must let the request
 * through to the container.
 *
 * Declared rather than left to the default: the CLI only applies the invoker
 * binding when it is named, so an interrupted deploy once left `resolveSpecies`
 * answering 403 HTML that the client could only report as `internal`.
 */
const PUBLIC_INVOKER = "public";

function isFirestoreTimestamp(value: unknown): value is Timestamp {
  return value instanceof Timestamp;
}

function isStale(lastSyncedAt: unknown): boolean {
  if (!isFirestoreTimestamp(lastSyncedAt)) {
    return true;
  }
  const ageDays =
    (Date.now() - lastSyncedAt.toMillis()) / (24 * 60 * 60 * 1000);
  return ageDays > CACHE_TTL_DAYS;
}

function toHttpsError(error: unknown): HttpsError {
  if (error instanceof TrefleError) {
    if (error.status === 404) {
      return new HttpsError("not-found", "No such species in the catalog.");
    }
    if (error.status === 429) {
      return new HttpsError(
        "resource-exhausted",
        "The plant catalog is rate limited right now. Try again shortly.",
      );
    }
    if (error.status === 401 || error.status === 403) {
      return new HttpsError(
        "failed-precondition",
        "The plant catalog rejected its access token.",
      );
    }
    return new HttpsError(
      "unavailable",
      `The plant catalog is unavailable (${error.status}).`,
    );
  }
  logger.error("Unexpected catalog failure", error);
  return new HttpsError("internal", "Could not reach the plant catalog.");
}

/** A learned vernacular key is a Firestore id, so it cannot contain a slash. */
function aliasDocId(key: string): boolean {
  return key.length >= 2 && key.length <= 700 && !key.includes("/");
}

async function cachedScientificName(key: string): Promise<string | null> {
  if (!aliasDocId(key)) {
    return null;
  }
  try {
    const snap = await db.doc(`vernacularAliases/${key}`).get();
    const name = snap.get("scientificName");
    return typeof name === "string" && name.trim() ? name.trim() : null;
  } catch (error) {
    logger.warn("Vernacular cache read failed", error);
    return null;
  }
}

async function cacheScientificName(
  key: string,
  scientificName: string,
): Promise<void> {
  if (!aliasDocId(key)) {
    return;
  }
  try {
    await db.doc(`vernacularAliases/${key}`).set({
      normalizedName: key,
      scientificName,
      source: "inaturalist",
      updatedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.warn("Vernacular cache write failed", error);
  }
}

/**
 * Shipped garden list, then the Firestore cache, then iNaturalist.
 * The first scientific name wins. A total miss returns null.
 */
async function resolveScientificName(query: string): Promise<{
  scientificName: string;
  matchedName: string;
} | null> {
  const key = normalizeVernacular(query);
  const matchedName = query.trim();
  const listed = lookupGardenName(key);
  if (listed) {
    return { scientificName: listed, matchedName };
  }

  const cached = await cachedScientificName(key);
  if (cached) {
    return { scientificName: cached, matchedName };
  }

  const learned = await fetchInaturalistScientificName(query);
  if (!learned) {
    return null;
  }
  await cacheScientificName(key, learned);
  return { scientificName: learned, matchedName };
}

async function attemptTrefleSearch(
  query: string,
  token: string,
  filters: SpeciesSearchFilters,
): Promise<{ ok: true; matches: TrefleSummary[] } | { ok: false; error: unknown }> {
  try {
    return {
      ok: true,
      matches: await searchTrefleSpecies(query, token, filters),
    };
  } catch (error) {
    return { ok: false, error };
  }
}

/**
 * Searches the catalog and returns summaries only.
 *
 * A typed common name is resolved to a scientific name first, then Trefle
 * `GET /plants/search` runs with that name. The original text is searched
 * too when it is not already the scientific name. Learned names are cached
 * in `vernacularAliases`. The client shows candidates and then calls
 * `resolveSpecies` for the pick.
 */
export const searchSpeciesCatalog = onCall(
  {
    region: DEFAULT_REGION,
    secrets: [TREFLE_API_TOKEN],
    enforceAppCheck: ENFORCE_APP_CHECK,
    invoker: PUBLIC_INVOKER,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to search for plants.");
    }

    const query = String(request.data?.query ?? "").trim();
    if (query.length < 2) {
      throw new HttpsError(
        "invalid-argument",
        "Provide at least two characters to search for.",
      );
    }

    const filters: SpeciesSearchFilters = {
      ranks: allowedList(request.data?.ranks, SEARCH_RANKS),
      families: allowedList(request.data?.families, SEARCH_FAMILIES),
      edible: request.data?.edible === true,
      vegetable: request.data?.vegetable === true,
    };

    try {
      const resolved = await resolveScientificName(query);
      const scientific = resolved?.scientificName ?? null;
      const searchScientific =
        scientific !== null &&
        normalizeVernacular(scientific) !== normalizeVernacular(query);
      const label =
        resolved &&
        normalizeVernacular(resolved.matchedName) !==
          normalizeVernacular(resolved.scientificName)
          ? resolved.matchedName
          : null;

      const token = TREFLE_API_TOKEN.value();
      const [aliasOutcome, directOutcome] = await Promise.all([
        searchScientific
          ? attemptTrefleSearch(scientific, token, filters)
          : Promise.resolve({ ok: true as const, matches: [] as TrefleSummary[] }),
        attemptTrefleSearch(query, token, filters),
      ]);

      const failures: unknown[] = [];
      if (searchScientific && !aliasOutcome.ok) {
        failures.push(aliasOutcome.error);
      }
      if (!directOutcome.ok) {
        failures.push(directOutcome.error);
      }
      if (failures.length === (searchScientific ? 2 : 1)) {
        throw failures[0];
      }

      const matches = mergeBySlug(
        aliasOutcome.ok ? aliasOutcome.matches : [],
        directOutcome.ok ? directOutcome.matches : [],
        searchScientific ? label : null,
      );
      return {
        attribution: TREFLE_ATTRIBUTION.attributionText,
        candidates: matches.slice(0, 20).map((match) => ({
          speciesId: toSpeciesId(match.scientific_name),
          scientificName: match.scientific_name,
          commonName: match.common_name,
          family: match.family,
          imageUrl: match.image_url,
          trefleSlug: match.slug,
          dataCompleteness: match.completion_ratio,
        })),
      };
    } catch (error) {
      throw toHttpsError(error);
    }
  },
);

/**
 * Caches one species into /species, then returns its id.
 *
 * This is the lazy half of the catalog strategy: nothing is mirrored up front,
 * and a species is fetched the first time someone actually wants it. Later
 * callers are served from Firestore until the record goes stale.
 *
 * Accepts either a `speciesId` we have already minted or a `trefleSlug` from
 * `searchSpeciesCatalog`.
 */
export const resolveSpecies = onCall(
  {
    region: DEFAULT_REGION,
    secrets: [TREFLE_API_TOKEN],
    enforceAppCheck: ENFORCE_APP_CHECK,
    invoker: PUBLIC_INVOKER,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to add a plant.");
    }

    const speciesId = request.data?.speciesId
      ? String(request.data.speciesId)
      : null;
    const trefleSlug = request.data?.trefleSlug
      ? String(request.data.trefleSlug)
      : null;

    if (!speciesId && !trefleSlug) {
      throw new HttpsError(
        "invalid-argument",
        "Provide either a speciesId or a trefleSlug.",
      );
    }

    // The cache read, the mapping and the write are all inside the same guard:
    // a Firestore or mapper failure here used to escape as a bare `internal`
    // with nothing logged to say why.
    try {
      // Serve from cache whenever we already hold a fresh copy.
      if (speciesId) {
        const cached = await db.doc(`species/${speciesId}`).get();
        if (cached.exists && !isStale(cached.data()?.lastSyncedAt)) {
          return { speciesId, cached: true };
        }
      }

      const detail = await fetchTrefleSpecies(
        trefleSlug ?? speciesId!,
        TREFLE_API_TOKEN.value(),
      );

      const resolvedId = toSpeciesId(detail.scientific_name);
      const speciesRef = db.doc(`species/${resolvedId}`);
      const sourceRef = speciesRef
        .collection("sources")
        .doc(TREFLE_ATTRIBUTION.provider);
      const profileRef = speciesRef
        .collection("careProfiles")
        .doc(DERIVED_CARE_PROFILE_ID);

      const existing = await speciesRef.get();
      const batch = db.batch();

      batch.set(
        speciesRef,
        {
          ...mapTrefleToSpecies(detail),
          ...(existing.exists
            ? {}
            : { createdAt: FieldValue.serverTimestamp() }),
        },
        { merge: true },
      );

      batch.set(sourceRef, mapTrefleToSource(detail), { merge: true });

      // Only derive a profile if nobody has hand-authored one, so curated care
      // advice is never overwritten by the automatic rules.
      const existingProfile = await profileRef.get();
      if (!existingProfile.exists || existingProfile.data()?.isDerived === true) {
        batch.set(
          profileRef,
          {
            ...deriveCareProfile(detail, TREFLE_ATTRIBUTION.provider),
            updatedAt: FieldValue.serverTimestamp(),
            schemaVersion: SCHEMA_VERSION,
          },
          { merge: true },
        );
      }

      await batch.commit();

      logger.info("Cached species from catalog", {
        speciesId: resolvedId,
        trefleId: detail.id,
        completeness: detail.completion_ratio,
      });

      return { speciesId: resolvedId, cached: false };
    } catch (error) {
      throw toHttpsError(error);
    }
  },
);
