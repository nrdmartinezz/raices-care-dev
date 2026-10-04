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

/** Shape of a record in `/plants` and `/plants/search`. Summaries only. */
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
  const separator = path.includes("?") ? "&" : "?";
  const url = `${BASE_URL}${path}${separator}token=${encodeURIComponent(token)}`;

  const response = await fetch(url, {
    headers: { Accept: "application/json" },
  });

  if (!response.ok) {
    // The URL carries the token, so it must never reach a log line.
    throw new TrefleError(
      `Trefle request to ${path} failed with ${response.status}`,
      response.status,
    );
  }

  return (await response.json()) as T;
}

/** Searches by common or scientific name. Returns summaries, not growth data. */
export async function searchTrefleSpecies(
  query: string,
  token: string,
): Promise<TrefleSummary[]> {
  const payload = await request<{ data: TrefleSummary[] }>(
    `/plants/search?q=${encodeURIComponent(query)}`,
    token,
  );
  return payload.data ?? [];
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
