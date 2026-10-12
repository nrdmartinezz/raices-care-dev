import { normalizePlantName } from "./plantsolve";

const SEARCH_URL = "https://api.floraapi.com/v1/search";

export type FloraHit = {
  id?: number;
  scientific_name?: string;
  common_names?: string[];
  taxonomic_rank?: string;
  usda_symbol?: string;
  light_requirements?: string[];
  soil_moisture?: string[];
  water_use?: string[];
  maintenance_tasks?: string[];
};

/** Exact common or scientific name. A species-rank row wins when several match. */
export function matchFloraHit(name: string, hits: FloraHit[]): FloraHit | null {
  const query = normalizePlantName(name);
  if (query.length < 2) return null;
  const exact = hits.filter((hit) => namesOf(hit).some((item) => normalizePlantName(item) === query));
  if (exact.length === 0) return null;
  const species = exact.filter((hit) => normalizePlantName(hit.taxonomic_rank ?? "") === "species");
  const pool = species.length > 0 ? species : exact;
  return [...pool].sort(
    (a, b) => (a.scientific_name ?? "").length - (b.scientific_name ?? "").length,
  )[0]!;
}

function namesOf(hit: FloraHit): string[] {
  return [hit.scientific_name ?? "", ...(hit.common_names ?? [])].filter((item) => item.trim());
}

/** 14 days when the profile says low or dry, 3 when high or wet, otherwise 7. */
export function floraWaterInterval(waterUse: string[], moisture: string[]): number {
  const text = [...waterUse, ...moisture].join(" ").toLowerCase();
  if (/\b(high|wet)\b/.test(text)) return 3;
  if (/\b(low|dry|drought)\b/.test(text)) return 14;
  return 7;
}

export function floraWaterInstructions(waterUse: string[], moisture: string[]): string | null {
  const parts = [
    waterUse.length > 0 ? `Water use: ${waterUse.join(", ")}.` : "",
    moisture.length > 0 ? `Soil moisture: ${moisture.join(", ")}.` : "",
  ].filter(Boolean);
  return parts.length > 0 ? parts.join(" ") : null;
}

export function floraSourceUrl(symbol: string | undefined): string {
  const trimmed = symbol?.trim();
  if (!trimmed) return "https://floraapi.com/docs/attribution";
  return `https://plants.usda.gov/plant-profile/${encodeURIComponent(trimmed)}`;
}

export function maintenanceNote(tasks: string[] | undefined, pattern: RegExp): string | null {
  for (const task of tasks ?? []) {
    const trimmed = task.trim();
    if (trimmed && pattern.test(trimmed)) return trimmed;
  }
  return null;
}

export async function fetchFloraSpecies(
  name: string,
  apiKey: string,
  fetchImpl: typeof fetch = fetch,
): Promise<FloraHit | null> {
  const searchUrl = new URL(SEARCH_URL);
  searchUrl.searchParams.set("q", name.trim());
  searchUrl.searchParams.set("limit", "10");
  const headers = { Authorization: `Bearer ${apiKey}` };
  const searchResponse = await fetchImpl(searchUrl, { headers });
  if (!searchResponse.ok) {
    throw new Error(`Flora search responded ${searchResponse.status}`);
  }
  const search = (await searchResponse.json()) as { results?: FloraHit[] };
  const hit = matchFloraHit(name, search.results ?? []);
  if (!hit?.id) return null;
  const detailResponse = await fetchImpl(`https://api.floraapi.com/v1/species/${hit.id}`, {
    headers,
  });
  if (!detailResponse.ok) {
    throw new Error(`Flora species responded ${detailResponse.status}`);
  }
  return (await detailResponse.json()) as FloraHit;
}
