import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";

/**
 * Trefle API token.
 *
 * Set it with `firebase functions:secrets:set TREFLE_API_TOKEN` and paste the
 * value at the prompt. It is never read from a file in this repo, and never
 * reaches the Flutter client — the client calls `resolveSpecies` instead.
 */
export const TREFLE_API_TOKEN = defineSecret("TREFLE_API_TOKEN");

const BASE_URL = "https://trefle.io/api/v1";

/** Free-tier ceiling is 60 requests per minute across the whole project. */
export const TREFLE_RATE_LIMIT_PER_MINUTE = 60;

/** Attribution required by Trefle's CC-BY-4.0 licence. */
export const TREFLE_ATTRIBUTION = {
  provider: "trefle",
  attributionText: "Data: Trefle.io (CC-BY-4.0)",
  license: "CC-BY-4.0",
  url: "https://trefle.io",
} as const;

interface Measurement {
  cm?: number | null;
  mm?: number | null;
  deg_c?: number | null;
  deg_f?: number | null;
}

/** Shape of a record from `GET /plants/search`. Summaries only. */
export interface TrefleSummary {
  id: number;
  slug: string;
  common_name: string | null;
  scientific_name: string;
  family: string | null;
  family_common_name: string | null;
  genus: string | null;
  rank: string | null;
  status: string | null;
  year: number | null;
  author: string | null;
  bibliography: string | null;
  image_url: string | null;
  synonyms: string[] | null;
  completion_ratio: number | null;
  complete_data: boolean | null;
  links: { self: string; plant: string; genus: string };
}

/**
 * Shape of `/species/{slug}`.
 *
 * Trefle's coverage is uneven: records in the sample response carried
 * completion ratios between 8% and 47% with `complete_data: false`. Treat
 * every field here as potentially absent.
 */
export interface TrefleGrowth {
  description?: string | null;
  sowing?: string | null;
  days_to_harvest?: number | null;
  /** 0–10 scale. */
  light?: number | null;
  /** 0–10 scale. */
  atmospheric_humidity?: number | null;
  /** 0–10 scale; Trefle's soil moisture requirement. */
  soil_humidity?: number | null;
  /** 0–10 scale. */
  soil_nutriments?: number | null;
  soil_salinity?: number | null;
  soil_texture?: number | null;
  ph_minimum?: number | null;
  ph_maximum?: number | null;
  minimum_precipitation?: Measurement | null;
  maximum_precipitation?: Measurement | null;
  minimum_temperature?: Measurement | null;
  maximum_temperature?: Measurement | null;
  minimum_root_depth?: Measurement | null;
  growth_months?: string[] | null;
  bloom_months?: string[] | null;
  fruit_months?: string[] | null;
}

export interface TrefleDetail extends TrefleSummary {
  common_names?: Record<string, string[]> | null;
  duration?: string[] | null;
  edible?: boolean | null;
  edible_part?: string[] | null;
  vegetable?: boolean | null;
  observations?: string | null;
  growth?: TrefleGrowth | null;
  specifications?: Record<string, unknown> | null;
  flower?: Record<string, unknown> | null;
  foliage?: Record<string, unknown> | null;
  fruit_or_seed?: Record<string, unknown> | null;
  sources?: Array<{
    id?: number;
    name?: string | null;
    url?: string | null;
    citation?: string | null;
    last_update?: string | null;
  }> | null;
}

class TrefleError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "TrefleError";
  }
}

async function request<T>(path: string, token: string): Promise<T> {
  // Secrets pasted at the prompt often keep a trailing newline or a copied
  // "Bearer " prefix. Either one makes Trefle reject an otherwise valid token.
  const cleanToken = token.trim().replace(/^Bearer\s+/i, "");
  const separator = path.includes("?") ? "&" : "?";
  const url = `${BASE_URL}${path}${separator}token=${encodeURIComponent(cleanToken)}`;

  const response = await fetch(url, {
    headers: { Accept: "application/json" },
  });

  if (!response.ok) {
    // The URL carries the token, so it must never reach a log line.
    logger.warn("Trefle request failed", {
      path,
      status: response.status,
    });
    throw new TrefleError(
      `Trefle request to ${path} failed with ${response.status}`,
      response.status,
    );
  }

  return (await response.json()) as T;
}

/**
 * Searches with the Plants search endpoint:
 * `GET /api/v1/plants/search?q=`.
 *
 * That `q` matches common names and scientific names. Everyday names are
 * what people type, so a common-name hit is kept and listed first. A query
 * with no common-name hit, such as a botanical name, keeps the full result.
 */
export async function searchTrefleSpecies(
  query: string,
  token: string,
): Promise<TrefleSummary[]> {
  const term = query.trim();
  const payload = await request<{ data: TrefleSummary[] }>(
    `/plants/search?q=${encodeURIComponent(term)}`,
    token,
  );
  return preferCommonName(payload.data ?? [], term.toLowerCase());
}

/**
 * Keeps matches whose common name contains the query, best match first.
 * Returns every result when none of the common names match.
 */
function preferCommonName(
  matches: TrefleSummary[],
  term: string,
): TrefleSummary[] {
  const scored = matches.map((match) => ({
    match,
    score: commonNameScore(match.common_name, term),
  }));
  const named = scored.filter((entry) => entry.score > 0);
  const pool = named.length > 0 ? named : scored;
  pool.sort((left, right) => right.score - left.score);
  return pool.map((entry) => entry.match);
}

/** Exact common name, then a name that starts with the query, then one that contains it. */
function commonNameScore(commonName: string | null, term: string): number {
  if (!commonName) {
    return 0;
  }
  const name = commonName.toLowerCase();
  if (name === term) {
    return 3;
  }
  if (name.startsWith(term)) {
    return 2;
  }
  if (name.includes(term)) {
    return 1;
  }
  return 0;
}

/** Fetches the full record, including the `growth` block care rules need. */
export async function fetchTrefleSpecies(
  slugOrId: string,
  token: string,
): Promise<TrefleDetail> {
  const payload = await request<{ data: TrefleDetail }>(
    `/species/${encodeURIComponent(slugOrId)}`,
    token,
  );
  return payload.data;
}

export { TrefleError };
