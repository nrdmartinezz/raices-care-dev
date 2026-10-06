import { FieldValue } from "../admin";
import {
  CareProfileDoc,
  CareProfileTask,
  SCHEMA_VERSION,
} from "../schema";
import { TREFLE_ATTRIBUTION, TrefleDetail } from "./trefle";

/**
 * Bump when the derivation rules below change, so stale profiles can be
 * recognised and re-derived from the stored source fields.
 */
export const CARE_RULES_VERSION = 1;

/**
 * Builds our own URL-safe document id from the scientific name.
 *
 * Trefle's own slug is already the kebab-cased scientific name, so this
 * usually agrees with it. Deriving it ourselves keeps the id stable if we ever
 * add a second provider whose slugs differ.
 */
export function toSpeciesId(scientificName: string): string {
  return scientificName
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120);
}

function flattenCommonNames(
  commonNames: TrefleDetail["common_names"],
): string[] {
  if (!commonNames) {
    return [];
  }
  const all = Object.values(commonNames).flat();
  return Array.from(new Set(all.filter((name): name is string => !!name)));
}

/**
 * Groups we can defend from Trefle's own flags.
 *
 * TODO: map species onto the seven Raíces categories (flowers, fruiting trees,
 * succulents, ornamental trees, houseplants, herbs, vegetables) with a rules
 * table in /plantCategories. Trefle exposes no field that answers this
 * directly, so it needs family and growth-habit heuristics we curate.
 */
function derivePlantGroups(detail: TrefleDetail): string[] {
  const groups = new Set<string>();
  if (detail.vegetable) {
    groups.add("vegetable");
  }
  if (detail.edible) {
    groups.add("edible");
  }
  for (const duration of detail.duration ?? []) {
    if (duration) {
      groups.add(duration.toLowerCase());
    }
  }
  return Array.from(groups);
}

/** The species catalog document, ready to merge into /species/{speciesId}. */
export function mapTrefleToSpecies(
  detail: TrefleDetail,
): Record<string, unknown> {
  const growth = detail.growth ?? {};

  return {
    slug: toSpeciesId(detail.scientific_name),
    scientificName: detail.scientific_name,
    commonName: detail.common_name,
    commonNames: flattenCommonNames(detail.common_names),
    synonyms: detail.synonyms ?? [],
    family: detail.family,
    familyCommonName: detail.family_common_name,
    genus: detail.genus,
    rank: detail.rank,
    taxonomicStatus: detail.status,
    author: detail.author,
    year: detail.year,
    plantGroups: derivePlantGroups(detail),

    externalIds: {
      trefle: String(detail.id),
      trefleSlug: detail.slug,
      floraCodex: null,
      gbif: null,
    },

    growth: {
      light: growth.light ?? null,
      atmosphericHumidity: growth.atmospheric_humidity ?? null,
      soilMoisture: growth.soil_humidity ?? null,
      soilNutriments: growth.soil_nutriments ?? null,
      soilTexture: growth.soil_texture ?? null,
      phMinimum: growth.ph_minimum ?? null,
      phMaximum: growth.ph_maximum ?? null,
      minimumTemperatureC: growth.minimum_temperature?.deg_c ?? null,
      maximumTemperatureC: growth.maximum_temperature?.deg_c ?? null,
      minimumPrecipitationMm: growth.minimum_precipitation?.mm ?? null,
      maximumPrecipitationMm: growth.maximum_precipitation?.mm ?? null,
      daysToHarvest: growth.days_to_harvest ?? null,
      growthMonths: growth.growth_months ?? [],
      bloomMonths: growth.bloom_months ?? [],
      fruitMonths: growth.fruit_months ?? [],
      sowing: growth.sowing ?? null,
      description: growth.description ?? null,
    },

    // Trefle serves images from third-party hosts that carry their own
    // attribution, so the URL is recorded rather than hotlinked blindly.
    // TODO: mirror into R2 at species/{speciesId}/cover.jpg once the
    // per-image licence of each upstream host has been checked.
    imageUrl: detail.image_url,
    imagePath: null,

    /** Trefle's own 0-100 estimate of how filled-in this record is. */
    dataCompleteness: detail.completion_ratio ?? null,
    hasCompleteData: detail.complete_data ?? false,

    attribution: {
      text: TREFLE_ATTRIBUTION.attributionText,
      license: TREFLE_ATTRIBUTION.license,
      url: TREFLE_ATTRIBUTION.url,
    },

    lastSyncedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    schemaVersion: SCHEMA_VERSION,
  };
}

/** Provenance record for /species/{speciesId}/sources/{provider}. */
export function mapTrefleToSource(
  detail: TrefleDetail,
): Record<string, unknown> {
  return {
    provider: TREFLE_ATTRIBUTION.provider,
    externalId: String(detail.id),
    externalSlug: detail.slug,
    externalUrl: `${TREFLE_ATTRIBUTION.url}/species/${detail.slug}`,
    license: TREFLE_ATTRIBUTION.license,
    attributionText: TREFLE_ATTRIBUTION.attributionText,
    bibliography: detail.bibliography ?? null,
    // Trefle aggregates institutional datasets that each keep their own
    // licence; these are the upstream citations for this record.
    upstreamSources: (detail.sources ?? []).map((source) => ({
      name: source.name ?? null,
      url: source.url ?? null,
      citation: source.citation ?? null,
      lastUpdate: source.last_update ?? null,
    })),
    fetchedAt: FieldValue.serverTimestamp(),
    schemaVersion: SCHEMA_VERSION,
  };
}

/**
 * Turns Trefle's 0–10 soil moisture requirement into a watering cadence.
 *
 * Deliberately coarse and explainable. Nothing here models weather, season or
 * container size; those belong in a later scheduling pass.
 */
function waterIntervalDays(soilMoisture: number | null): number {
  if (soilMoisture === null) {
    return 7;
  }
  if (soilMoisture >= 7) {
    return 3;
  }
  if (soilMoisture >= 4) {
    return 7;
  }
  return 14;
}

function fertilizeIntervalDays(soilNutriments: number | null): number {
  return soilNutriments !== null && soilNutriments >= 7 ? 21 : 30;
}

/**
 * Derives a starter care profile from catalog growth data.
 *
 * Trefle carries no care schedules, only tolerances, so every cadence here is
 * ours. `basis` records which source fields fed each one, so profiles can be
 * re-derived when CARE_RULES_VERSION changes.
 */
export function deriveCareProfile(
  detail: TrefleDetail,
  sourceId: string,
): CareProfileDoc {
  const growth = detail.growth ?? {};
  const soilMoisture = growth.soil_humidity ?? null;
  const soilNutriments = growth.soil_nutriments ?? null;

  const tasks: CareProfileTask[] = [
    {
      taskType: "water_check",
      title: "Check soil moisture",
      instructions:
        "Press a knuckle into the top of the soil. Water only if it comes away dry.",
      intervalDays: waterIntervalDays(soilMoisture),
      priority: "normal",
      basis: soilMoisture === null ? [] : ["growth.soil_humidity"],
    },
    {
      taskType: "fertilize",
      title: "Feed the plant",
      instructions: "Apply a balanced feed at half the labelled strength.",
      intervalDays: fertilizeIntervalDays(soilNutriments),
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

  return {
    label: "Derived from catalog data",
    isDerived: true,
    derivedFrom: {
      provider: TREFLE_ATTRIBUTION.provider,
      sourceId,
      fields: ["growth.soil_humidity", "growth.soil_nutriments"],
    },
    tasks,
    schemaVersion: SCHEMA_VERSION,
  };
}
