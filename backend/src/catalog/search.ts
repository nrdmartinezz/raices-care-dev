import { ApiError } from "../http/errors";
import { now } from "../http/ids";
import {
  fetchInaturalistScientificName,
  lookupGardenName,
  mergeBySlug,
  normalizeVernacular,
} from "./vernacular";
import {
  TREFLE_ATTRIBUTION,
  TrefleDetail,
  TrefleError,
  TrefleSummary,
  commonNameList,
  deriveCareTasks,
  fetchTrefleSpecies,
  plantGroups,
  searchTrefleSpecies,
  toSpeciesId,
  type SpeciesSearchFilters,
} from "./trefle";

const CACHE_TTL_MS = 90 * 24 * 60 * 60 * 1000;

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

export interface CatalogHit {
  id: string;
  scientificName: string;
  commonNames: string[];
  plantGroups: string[];
  imageUrl: string | null;
  trefleSlug: string | null;
  family: string | null;
  dataCompleteness: number | null;
}

export function allowedList(value: string | undefined, allowed: Set<string>): string[] {
  if (!value) return [];
  return value.split(",").map((item) => item.trim()).filter((item) => allowed.has(item));
}

export function searchFilters(query: {
  rank?: string;
  family?: string;
  edible?: string;
  vegetable?: string;
}): SpeciesSearchFilters {
  return {
    ranks: allowedList(query.rank, SEARCH_RANKS),
    families: allowedList(query.family, SEARCH_FAMILIES),
    edible: query.edible === "true",
    vegetable: query.vegetable === "true",
  };
}

function aliasKey(normalized: string): string | null {
  if (normalized.length < 2 || normalized.length > 700 || normalized.includes("/")) {
    return null;
  }
  return normalized;
}

async function cachedScientificName(
  db: D1Database,
  key: string,
): Promise<string | null> {
  if (!aliasKey(key)) return null;
  try {
    const row = await db
      .prepare(
        "SELECT scientific_name FROM vernacular_aliases WHERE normalized_name = ?",
      )
      .bind(key)
      .first<{ scientific_name: string }>();
    const name = row?.scientific_name?.trim();
    return name ? name : null;
  } catch (error) {
    console.warn("Vernacular cache read failed", error);
    return null;
  }
}

async function cacheScientificName(
  db: D1Database,
  key: string,
  scientificName: string,
): Promise<void> {
  if (!aliasKey(key)) return;
  try {
    await db
      .prepare(
        `INSERT INTO vernacular_aliases (normalized_name, scientific_name, source, updated_at)
         VALUES (?, ?, 'inaturalist', ?)
         ON CONFLICT(normalized_name) DO UPDATE SET
           scientific_name = excluded.scientific_name,
           source = excluded.source,
           updated_at = excluded.updated_at`,
      )
      .bind(key, scientificName, now())
      .run();
  } catch (error) {
    console.warn("Vernacular cache write failed", error);
  }
}

/** Garden list, then D1, then iNaturalist. The first scientific name wins. */
export async function resolveScientificName(
  db: D1Database,
  query: string,
  token: string | undefined,
): Promise<{ scientificName: string; matchedName: string } | null> {
  const key = normalizeVernacular(query);
  const matchedName = query.trim();
  const listed = lookupGardenName(key);
  if (listed) return { scientificName: listed, matchedName };

  const cached = await cachedScientificName(db, key);
  if (cached) return { scientificName: cached, matchedName };

  if (!token) return null;
  const learned = await fetchInaturalistScientificName(query);
  if (!learned) return null;
  await cacheScientificName(db, key, learned);
  return { scientificName: learned, matchedName };
}

export async function findLocalSpeciesIds(
  db: D1Database,
  terms: string[],
  limit: number,
): Promise<string[]> {
  const ids: string[] = [];
  const seen = new Set<string>();
  for (const term of terms) {
    const query = term.trim();
    if (query.length < 2) continue;
    let found: string[] = [];
    const match = query
      .replace(/["*]/g, " ")
      .split(/\s+/)
      .filter(Boolean)
      .map((part) => `"${part}"*`)
      .join(" ");
    try {
      const rows = await db
        .prepare(
          "SELECT species_id FROM species_fts WHERE species_fts MATCH ? LIMIT ?",
        )
        .bind(match, limit)
        .all<{ species_id: string }>();
      found = (rows.results ?? []).map((row) => row.species_id);
    } catch {
      found = [];
    }
    if (found.length === 0) {
      const like = `%${query.replace(/[%_]/g, "")}%`;
      const rows = await db
        .prepare(
          `SELECT id FROM species
           WHERE scientific_name LIKE ? OR common_names_json LIKE ?
           ORDER BY scientific_name LIMIT ?`,
        )
        .bind(like, like, limit)
        .all<{ id: string }>();
      found = (rows.results ?? []).map((row) => row.id);
    }
    for (const id of found) {
      if (seen.has(id)) continue;
      seen.add(id);
      ids.push(id);
      if (ids.length >= limit) return ids;
    }
  }
  return ids;
}

async function trefleSearch(
  query: string,
  token: string,
  filters: SpeciesSearchFilters,
): Promise<TrefleSummary[] | null> {
  try {
    return await searchTrefleSpecies(query, token, filters);
  } catch (error) {
    console.warn("Trefle search failed", error instanceof Error ? error.message : error);
    return null;
  }
}

export async function liveCatalogHits(
  db: D1Database,
  query: string,
  token: string | undefined,
  filters: SpeciesSearchFilters,
): Promise<{ hits: CatalogHit[]; attribution: string | null; scientificName: string | null }> {
  const resolved = await resolveScientificName(db, query, token);
  const scientific = resolved?.scientificName ?? null;
  if (!token) {
    return { hits: [], attribution: null, scientificName: scientific };
  }
  const searchScientific =
    scientific !== null &&
    normalizeVernacular(scientific) !== normalizeVernacular(query);
  const label =
    resolved &&
    normalizeVernacular(resolved.matchedName) !==
      normalizeVernacular(resolved.scientificName)
      ? resolved.matchedName
      : null;

  const [aliasHits, directHits] = await Promise.all([
    searchScientific ? trefleSearch(scientific, token, filters) : Promise.resolve([]),
    trefleSearch(query, token, filters),
  ]);
  if (aliasHits === null && directHits === null) {
    return { hits: [], attribution: null, scientificName: scientific };
  }
  const merged = mergeBySlug(
    aliasHits ?? [],
    directHits ?? [],
    searchScientific ? label : null,
  );
  return {
    hits: merged.slice(0, 20).map(toHit),
    attribution: merged.length > 0 ? TREFLE_ATTRIBUTION : null,
    scientificName: scientific,
  };
}

function toHit(match: TrefleSummary): CatalogHit {
  const names = match.common_name ? [match.common_name] : [];
  return {
    id: toSpeciesId(match.scientific_name),
    scientificName: match.scientific_name,
    commonNames: names,
    plantGroups: [],
    imageUrl: match.image_url,
    trefleSlug: match.slug,
    family: match.family,
    dataCompleteness:
      match.completion_ratio == null ? null : Math.round(match.completion_ratio),
  };
}

type SpeciesCacheRow = {
  id: string;
  updated_at: number;
  source: string | null;
  source_id: string | null;
};

export async function upsertTrefleSpecies(
  db: D1Database,
  detail: TrefleDetail,
): Promise<string> {
  const id = toSpeciesId(detail.scientific_name);
  if (!id) {
    throw new ApiError(502, "upstream_error", "The catalog returned no species id.");
  }
  const ts = now();
  const names = commonNameList(detail);
  await db
    .prepare(
      `INSERT INTO species (
        id, scientific_name, common_names_json, plant_groups_json, toxicity_json,
        image_url, source, source_id, created_at, updated_at
      ) VALUES (?, ?, ?, ?, '{}', ?, 'trefle', ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        scientific_name = excluded.scientific_name,
        common_names_json = excluded.common_names_json,
        plant_groups_json = excluded.plant_groups_json,
        image_url = excluded.image_url,
        source = 'trefle',
        source_id = excluded.source_id,
        updated_at = excluded.updated_at`,
    )
    .bind(
      id,
      detail.scientific_name,
      JSON.stringify(names),
      JSON.stringify(plantGroups(detail)),
      detail.image_url,
      detail.slug,
      ts,
      ts,
    )
    .run();

  const profileId = `${id}__derived`;
  await db
    .prepare(
      `INSERT INTO care_profiles (id, species_id, name, tasks_json, created_at, updated_at)
       VALUES (?, ?, 'Derived from catalog data', ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         tasks_json = excluded.tasks_json,
         name = excluded.name,
         updated_at = excluded.updated_at`,
    )
    .bind(profileId, id, JSON.stringify(deriveCareTasks(detail)), ts, ts)
    .run();
  return id;
}

export async function loadCachedSpecies(
  db: D1Database,
  speciesId: string | undefined,
  trefleSlug: string | undefined,
): Promise<SpeciesCacheRow | null> {
  if (speciesId) {
    const row = await db
      .prepare("SELECT id, updated_at, source, source_id FROM species WHERE id = ?")
      .bind(speciesId)
      .first<SpeciesCacheRow>();
    if (row) return row;
  }
  if (!trefleSlug) return null;
  return db
    .prepare(
      `SELECT id, updated_at, source, source_id FROM species
       WHERE source_id = ? OR id = ?`,
    )
    .bind(trefleSlug, trefleSlug)
    .first<SpeciesCacheRow>();
}

export function isFresh(updatedAt: number): boolean {
  return now() - updatedAt < CACHE_TTL_MS;
}

export async function fetchAndStoreSpecies(
  db: D1Database,
  slugOrId: string,
  token: string,
): Promise<string> {
  try {
    const detail = await fetchTrefleSpecies(slugOrId, token);
    return upsertTrefleSpecies(db, detail);
  } catch (error) {
    if (error instanceof TrefleError) {
      if (error.status === 404) {
        throw new ApiError(404, "not_found", "No such species in the catalog.");
      }
      if (error.status === 429) {
        throw new ApiError(
          429,
          "rate_limited",
          "The plant catalog is rate limited right now. Try again shortly.",
        );
      }
      throw new ApiError(
        503,
        "upstream_unavailable",
        `The plant catalog is unavailable (${error.status}).`,
      );
    }
    throw error;
  }
}

export function requireTrefleToken(token: string | undefined): string {
  const clean = token?.trim();
  if (!clean) {
    throw new ApiError(
      503,
      "failed_precondition",
      "The plant catalog token is not configured.",
    );
  }
  return clean;
}
