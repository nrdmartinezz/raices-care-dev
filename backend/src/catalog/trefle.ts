const BASE_URL = "https://trefle.io/api/v1";

export const TREFLE_ATTRIBUTION = "Data: Trefle.io (CC-BY-4.0)";

export class TrefleError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "TrefleError";
  }
}

interface Measurement {
  deg_c?: number | null;
}

export interface TrefleSummary {
  id: number;
  slug: string;
  common_name: string | null;
  scientific_name: string;
  family: string | null;
  genus: string | null;
  rank: string | null;
  image_url: string | null;
  completion_ratio: number | null;
  vegetable?: boolean | null;
  edible?: boolean | null;
  duration?: string[] | null;
}

export interface TrefleDetail extends TrefleSummary {
  common_names?: Record<string, string[]> | null;
  growth?: {
    soil_humidity?: number | null;
    soil_nutriments?: number | null;
    minimum_temperature?: Measurement | null;
    maximum_temperature?: Measurement | null;
  } | null;
}

export interface SpeciesSearchFilters {
  ranks?: string[];
  families?: string[];
  edible?: boolean;
  vegetable?: boolean;
}

async function request<T>(path: string, token: string): Promise<T> {
  const cleanToken = token.trim().replace(/^Bearer\s+/i, "");
  const separator = path.includes("?") ? "&" : "?";
  const url = `${BASE_URL}${path}${separator}token=${encodeURIComponent(cleanToken)}`;
  const response = await fetch(url, { headers: { Accept: "application/json" } });
  if (!response.ok) {
    throw new TrefleError(`Trefle request failed with ${response.status}`, response.status);
  }
  return (await response.json()) as T;
}

export async function searchTrefleSpecies(
  query: string,
  token: string,
  filters: SpeciesSearchFilters = {},
): Promise<TrefleSummary[]> {
  const term = query.trim();
  const params = new URLSearchParams();
  params.set("q", term);
  if (filters.ranks?.length) params.set("filter[rank]", filters.ranks.join(","));
  if (filters.families?.length) {
    params.set("filter[family_name]", filters.families.join(","));
  }
  if (filters.edible) params.set("filter[edible]", "true");
  if (filters.vegetable) params.set("filter[vegetable]", "true");
  const payload = await request<{ data: TrefleSummary[] }>(
    `/plants/search?${params.toString()}`,
    token,
  );
  return preferCommonName(payload.data ?? [], term.toLowerCase());
}

function preferCommonName(matches: TrefleSummary[], term: string): TrefleSummary[] {
  const scored = matches.map((match) => ({
    match,
    score: commonNameScore(match.common_name, term),
  }));
  const named = scored.filter((entry) => entry.score > 0);
  const pool = named.length > 0 ? named : scored;
  pool.sort((left, right) => right.score - left.score);
  return pool.map((entry) => entry.match);
}

function commonNameScore(commonName: string | null, term: string): number {
  if (!commonName) return 0;
  const name = commonName.toLowerCase();
  if (name === term) return 3;
  if (name.startsWith(term)) return 2;
  if (name.includes(term)) return 1;
  return 0;
}

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

export function toSpeciesId(scientificName: string): string {
  return scientificName
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120);
}

export function deriveCareTasks(detail: TrefleDetail): Array<{
  taskType: string;
  title: string;
  instructions: string;
  intervalDays: number;
  priority: string;
  basis: string[];
}> {
  const soilMoisture = detail.growth?.soil_humidity ?? null;
  const soilNutriments = detail.growth?.soil_nutriments ?? null;
  const waterDays =
    soilMoisture === null ? 7 : soilMoisture >= 7 ? 3 : soilMoisture >= 4 ? 7 : 14;
  return [
    {
      taskType: "water_check",
      title: "Check soil moisture",
      instructions:
        "Press a knuckle into the top of the soil. Water only if it comes away dry.",
      intervalDays: waterDays,
      priority: "normal",
      basis: soilMoisture === null ? [] : ["growth.soil_humidity"],
    },
    {
      taskType: "fertilize",
      title: "Feed the plant",
      instructions: "Apply a balanced feed at half the labelled strength.",
      intervalDays: soilNutriments !== null && soilNutriments >= 7 ? 21 : 30,
      priority: "low",
      basis: soilNutriments === null ? [] : ["growth.soil_nutriments"],
    },
    {
      taskType: "pest_check",
      title: "Inspect for pests",
      instructions:
        "Look under the leaves and along new growth for insects or damage.",
      intervalDays: 14,
      priority: "low",
      basis: [],
    },
  ];
}

export function plantGroups(detail: TrefleDetail): string[] {
  const groups = new Set<string>();
  if (detail.vegetable) groups.add("vegetable");
  if (detail.edible) groups.add("edible");
  for (const duration of detail.duration ?? []) {
    if (duration) groups.add(duration.toLowerCase());
  }
  return [...groups];
}

export function commonNameList(detail: TrefleDetail): string[] {
  const names = new Set<string>();
  if (detail.common_name) names.add(detail.common_name);
  for (const list of Object.values(detail.common_names ?? {})) {
    for (const name of list) {
      if (name) names.add(name);
    }
  }
  return [...names];
}
