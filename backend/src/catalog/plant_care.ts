import {
  fetchFloraSpecies,
  floraSourceUrl,
  floraWaterInstructions,
  floraWaterInterval,
  maintenanceNote,
  type FloraHit,
} from "./flora";
import { deriveCareTasks, type TrefleDetail } from "./trefle";
import {
  clipCareText,
  fetchPlantSolveProfile,
  pestNote,
  plantSolveSourceUrl,
  type PlantSolveProfile,
} from "./plantsolve";
import { readJson } from "../http/ids";

export type PlantCareTask = ReturnType<typeof deriveCareTasks>[number];

export type PlantCareRecord = {
  tasks: PlantCareTask[];
  difficulty: string | null;
  light: string | null;
  sourceUrl: string | null;
  sourceLabel: string | null;
};

/** Water every 7 days, feed every 30, and a pest check every 14. */
export function defaultCareTasks(): PlantCareTask[] {
  return deriveCareTasks({ growth: null } as TrefleDetail);
}

export function emptyPlantCare(): PlantCareRecord {
  return { tasks: [], difficulty: null, light: null, sourceUrl: null, sourceLabel: null };
}

/** A stored object, or an older bare task array. */
export function readPlantCare(raw: string | null | undefined): PlantCareRecord {
  const parsed = readJson<unknown>(raw, null);
  if (Array.isArray(parsed)) {
    return { ...emptyPlantCare(), tasks: parsed as PlantCareTask[] };
  }
  if (!parsed || typeof parsed !== "object") return emptyPlantCare();
  const record = parsed as {
    tasks?: unknown;
    difficulty?: unknown;
    light?: unknown;
    sourceUrl?: unknown;
    sourceLabel?: unknown;
  };
  const sourceUrl = clipCareText(typeof record.sourceUrl === "string" ? record.sourceUrl : undefined, 300);
  return {
    tasks: Array.isArray(record.tasks) ? (record.tasks as PlantCareTask[]) : [],
    difficulty: clipCareText(typeof record.difficulty === "string" ? record.difficulty : undefined, 80),
    light: clipCareText(typeof record.light === "string" ? record.light : undefined),
    sourceUrl,
    sourceLabel: careSourceLabel(
      typeof record.sourceLabel === "string" ? record.sourceLabel : undefined,
      sourceUrl,
    ),
  };
}

export function writePlantCare(record: PlantCareRecord): string {
  return JSON.stringify({
    tasks: record.tasks,
    difficulty: record.difficulty,
    light: record.light,
    sourceUrl: record.sourceUrl,
    sourceLabel: record.sourceLabel,
  });
}

/** Tips from a PlantSolve profile, on the same three chores and default intervals. */
export function careFromProfile(profile: PlantSolveProfile, slug: string): PlantCareRecord {
  const watering = clipCareText(profile.care?.watering);
  const feeding = clipCareText(profile.nutrients?.fertilizerFrequency);
  const pests = pestNote(profile);
  const tasks = defaultCareTasks().map((task) => {
    if (task.taskType === "water_check" && watering) return { ...task, instructions: watering };
    if (task.taskType === "fertilize" && feeding) return { ...task, instructions: feeding };
    if (task.taskType === "pest_check" && pests) return { ...task, instructions: pests };
    return task;
  });
  return {
    tasks,
    difficulty: clipCareText(profile.care?.difficulty, 80),
    light: clipCareText(profile.lighting?.description),
    sourceUrl: plantSolveSourceUrl(slug),
    sourceLabel: "PlantSolve",
  };
}

/** Growing conditions from Flora, on the same three chores. */
export function careFromFlora(species: FloraHit): PlantCareRecord {
  const waterUse = cleanList(species.water_use);
  const moisture = cleanList(species.soil_moisture);
  const watering = clipCareText(floraWaterInstructions(waterUse, moisture) ?? undefined);
  const feeding = clipCareText(maintenanceNote(species.maintenance_tasks, /fertil|feed/i) ?? undefined);
  const pests = clipCareText(maintenanceNote(species.maintenance_tasks, /pest/i) ?? undefined);
  const tasks = defaultCareTasks().map((task) => {
    if (task.taskType === "water_check" && watering) {
      return { ...task, instructions: watering, intervalDays: floraWaterInterval(waterUse, moisture) };
    }
    if (task.taskType === "fertilize" && feeding) return { ...task, instructions: feeding };
    if (task.taskType === "pest_check" && pests) return { ...task, instructions: pests };
    return task;
  });
  return {
    tasks,
    difficulty: null,
    light: clipCareText(cleanList(species.light_requirements).join(", ") || undefined),
    sourceUrl: floraSourceUrl(species.usda_symbol),
    sourceLabel: "Flora",
  };
}

function cleanList(values: string[] | undefined): string[] {
  return (values ?? []).map((item) => item.trim()).filter(Boolean);
}

function careSourceLabel(label: string | undefined, sourceUrl: string | null): string | null {
  const explicit = clipCareText(label, 40);
  if (explicit) return explicit;
  if (sourceUrl?.includes("plantsolve.com")) return "PlantSolve";
  return null;
}

export type CareLookupOptions = {
  fetchImpl?: typeof fetch;
  floraApiKey?: string;
};

/**
 * Care for the name the person typed. PlantSolve is first. Flora is the
 * fallback. A miss in both still returns the defaults.
 */
export async function careForName(
  name: string,
  options: CareLookupOptions = {},
): Promise<PlantCareRecord> {
  const fallback: PlantCareRecord = {
    tasks: defaultCareTasks(),
    difficulty: null,
    light: null,
    sourceUrl: null,
    sourceLabel: null,
  };
  if (name.trim().length < 2) return fallback;
  const fetchImpl = options.fetchImpl ?? fetch;
  try {
    const found = await fetchPlantSolveProfile(name, fetchImpl);
    if (found) return careFromProfile(found.profile, found.slug);
  } catch (error) {
    console.warn(
      "PlantSolve care lookup failed",
      error instanceof Error ? error.message : error,
    );
  }
  const floraApiKey = options.floraApiKey?.trim();
  if (!floraApiKey) return fallback;
  try {
    const species = await fetchFloraSpecies(name, floraApiKey, fetchImpl);
    if (!species) return fallback;
    return careFromFlora(species);
  } catch (error) {
    console.warn(
      "Flora care lookup failed",
      error instanceof Error ? error.message : error,
    );
    return fallback;
  }
}
