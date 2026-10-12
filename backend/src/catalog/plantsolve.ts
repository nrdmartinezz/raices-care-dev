const INDEX_URL = "https://www.plantsolve.com/api/v1/plants/index.json";

export type PlantSolveIndexItem = { slug?: string };

export type PlantSolveProfile = {
  care?: { difficulty?: string; watering?: string };
  lighting?: { description?: string };
  nutrients?: { fertilizerFrequency?: string };
  relationships?: Array<{
    type?: string;
    relationship?: string;
    strength?: number;
    notes?: string;
  }>;
};

/** Lowercase, drop accents, and treat hyphens as spaces. */
export function normalizePlantName(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[-_]+/g, " ")
    .replace(/[^a-z0-9 ]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** Slug key with a trailing "care" suffix removed, so `golden-pothos-care` matches "golden pothos". */
function slugKey(slug: string): string {
  const normalized = normalizePlantName(slug);
  return normalized.endsWith(" care") ? normalized.slice(0, -" care".length).trim() : normalized;
}

/**
 * Exact slug match. `monstera` stays `monstera` when `monstera-albo` is also listed.
 * Returns null when nothing matches exactly.
 */
export function matchPlantSolveSlug(name: string, slugs: string[]): string | null {
  const query = normalizePlantName(name);
  if (query.length < 2) return null;
  const strict = slugs.filter((slug) => normalizePlantName(slug) === query);
  if (strict.length > 0) return shortest(strict);
  const relaxed = slugs.filter((slug) => slugKey(slug) === query);
  if (relaxed.length > 0) return shortest(relaxed);
  return null;
}

function shortest(slugs: string[]): string {
  return [...slugs].sort((a, b) => a.length - b.length || a.localeCompare(b))[0]!;
}

export function plantSolveSourceUrl(slug: string): string {
  return `https://www.plantsolve.com/plants/${slug}`;
}

export function clipCareText(value: string | undefined, max = 500): string | null {
  const trimmed = value?.replace(/\s+/g, " ").trim() ?? "";
  if (!trimmed) return null;
  return trimmed.length <= max ? trimmed : trimmed.slice(0, max).trim();
}

/** The vulnerability note with the highest strength, when the profile lists one. */
export function pestNote(profile: PlantSolveProfile): string | null {
  let best: { strength: number; notes: string } | null = null;
  for (const item of profile.relationships ?? []) {
    const kind = item.type ?? item.relationship;
    if (kind !== "vulnerability") continue;
    const notes = clipCareText(item.notes);
    if (!notes) continue;
    const strength = typeof item.strength === "number" ? item.strength : 0;
    if (!best || strength > best.strength) best = { strength, notes };
  }
  return best?.notes ?? null;
}

export async function fetchPlantSolveProfile(
  name: string,
  fetchImpl: typeof fetch = fetch,
): Promise<{ slug: string; profile: PlantSolveProfile } | null> {
  const indexResponse = await fetchImpl(INDEX_URL);
  if (!indexResponse.ok) {
    throw new Error(`PlantSolve index responded ${indexResponse.status}`);
  }
  const index = (await indexResponse.json()) as PlantSolveIndexItem[];
  if (!Array.isArray(index)) throw new Error("PlantSolve index was not a list");
  const slugs = index.flatMap((item) => (item.slug ? [item.slug] : []));
  const slug = matchPlantSolveSlug(name, slugs);
  if (!slug) return null;
  const detailResponse = await fetchImpl(
    `https://www.plantsolve.com/api/v1/plants/${encodeURIComponent(slug)}.json`,
  );
  if (!detailResponse.ok) {
    throw new Error(`PlantSolve profile responded ${detailResponse.status}`);
  }
  const profile = (await detailResponse.json()) as PlantSolveProfile;
  return { slug, profile };
}
