import {
  GROWING_METHODS,
  LIFE_STAGES,
  LIGHT_LEVELS,
  LOCATIONS,
  SEASONS,
  SOIL_TYPES,
  TASK_TYPES,
  WATER_STRATEGIES,
  WATER_TRIGGERS,
  zoneRank,
  type CareRuleJson,
} from "./care_rules.ts";

export type CareImportError = {
  table: string;
  row: number;
  message: string;
};

export type SpeciesRow = {
  id: string;
  scientificName: string;
  primaryCommonName: string;
  defaultCareProfileId: string;
  status: string;
  aliases: string[];
};

export type ProfileRow = {
  id: string;
  speciesId: string;
  name: string;
  appliesToJson: string;
  status: string;
  version: number;
  reviewedAt: number | null;
  sourceRefs: string[];
};

export type RuleRow = {
  id: string;
  careProfileId: string;
  taskType: string;
  ruleJson: string;
  displayOrder: number;
  status: string;
};

export type SourceRow = {
  id: string;
  name: string;
  url: string;
  license: string;
  retrievedAt: number;
};

export type CareBundle = {
  species: SpeciesRow[];
  profiles: ProfileRow[];
  rules: RuleRow[];
  sources: SourceRow[];
};

const PROFILE_STATUSES = ["draft", "needs_review", "reviewed", "published", "archived"];
const SPECIES_STATUSES = ["draft", "published", "archived"];
const FIXED_SCHEDULE = /every\s+\d+\s+days?/i;
const DOSAGE = /\b(ml|tbsp|tablespoons?|teaspoons?|cups?|npk|miracle-gro)\b/i;
const PESTICIDE = /\b(pesticide|insecticide|herbicide)\b/i;

export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          cell += '"';
          i += 1;
        } else {
          quoted = false;
        }
      } else {
        cell += ch;
      }
      continue;
    }
    if (ch === '"') {
      quoted = true;
    } else if (ch === ",") {
      row.push(cell);
      cell = "";
    } else if (ch === "\n") {
      row.push(cell);
      rows.push(row);
      row = [];
      cell = "";
    } else if (ch !== "\r") {
      cell += ch;
    }
  }
  if (cell.length > 0 || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }
  return rows.filter((record) => record.some((value) => value.trim() !== ""));
}

function headerIndex(header: string[], name: string): number {
  return header.findIndex((column) => column.trim() === name);
}

function cell(record: string[], index: number): string {
  if (index < 0) return "";
  return (record[index] ?? "").trim();
}

function slug(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120);
}

export function bundleFromCsv(files: {
  species: string;
  profiles: string;
  rules: string;
  sources: string;
}): { bundle: CareBundle; errors: CareImportError[] } {
  const errors: CareImportError[] = [];
  const species = readTable(files.species, "species", errors, (record, header, row) => {
    const scientificName = cell(record, headerIndex(header, "scientific_name"));
    const id =
      cell(record, headerIndex(header, "id")) ||
      slug(scientificName);
    const aliases = cell(record, headerIndex(header, "aliases"))
      .split(";")
      .map((alias) => alias.trim())
      .filter(Boolean);
    return {
      id,
      scientificName,
      primaryCommonName: cell(record, headerIndex(header, "primary_common_name")),
      defaultCareProfileId: cell(record, headerIndex(header, "default_care_profile_id")),
      status: cell(record, headerIndex(header, "status")) || "draft",
      aliases,
    };
  });
  const profiles = readTable(files.profiles, "care_profiles", errors, (record, header) => {
    const speciesId = cell(record, headerIndex(header, "species_id"));
    const profileName = cell(record, headerIndex(header, "name"));
    const id =
      cell(record, headerIndex(header, "id")) ||
      `${speciesId}__${slug(profileName)}`;
    const reviewed = cell(record, headerIndex(header, "reviewed_at"));
    return {
      id,
      speciesId,
      name: profileName,
      appliesToJson: cell(record, headerIndex(header, "applies_to_json")) || "{}",
      status: cell(record, headerIndex(header, "status")) || "draft",
      version: Number(cell(record, headerIndex(header, "version")) || "1"),
      reviewedAt: reviewed ? Number(reviewed) : null,
      sourceRefs: readStringArray(cell(record, headerIndex(header, "source_refs_json"))),
    };
  });
  const rules = readTable(files.rules, "care_rules", errors, (record, header) => {
    const careProfileId = cell(record, headerIndex(header, "care_profile_id"));
    const taskType = cell(record, headerIndex(header, "task_type"));
    const displayOrder = Number(cell(record, headerIndex(header, "display_order")) || "0");
    const id =
      cell(record, headerIndex(header, "id")) ||
      `${careProfileId}__${taskType}__${displayOrder}`;
    return {
      id,
      careProfileId,
      taskType,
      ruleJson: cell(record, headerIndex(header, "rule_json")) || "{}",
      displayOrder,
      status: cell(record, headerIndex(header, "status")) || "draft",
    };
  });
  const sources = readTable(files.sources, "data_sources", errors, (record, header) => {
    const name = cell(record, headerIndex(header, "name"));
    return {
      id: cell(record, headerIndex(header, "id")) || slug(name),
      name,
      url: cell(record, headerIndex(header, "url")),
      license: cell(record, headerIndex(header, "license")),
      retrievedAt: Number(cell(record, headerIndex(header, "retrieved_at")) || "0"),
    };
  });
  return { bundle: { species, profiles, rules, sources }, errors };
}

function readTable<T>(
  text: string,
  table: string,
  errors: CareImportError[],
  map: (record: string[], header: string[], row: number) => T,
): T[] {
  const records = parseCsv(text);
  if (records.length === 0) return [];
  const header = records[0] ?? [];
  return records.slice(1).map((record, index) => map(record, header, index + 2));
}

function readStringArray(raw: string): string[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((item): item is string => typeof item === "string");
  } catch {
    return [];
  }
}

function known(values: readonly string[], value: string): boolean {
  return values.includes(value);
}

function stringList(value: unknown): string[] {
  if (typeof value === "string") return [value];
  if (Array.isArray(value)) return value.filter((item): item is string => typeof item === "string");
  return [];
}

export function validateCareBundle(bundle: CareBundle): CareImportError[] {
  const errors: CareImportError[] = [];
  const speciesById = new Map(bundle.species.map((species) => [species.id, species]));
  const profilesById = new Map(bundle.profiles.map((profile) => [profile.id, profile]));
  const sourcesById = new Map(bundle.sources.map((source) => [source.id, source]));
  const scientific = new Set<string>();
  const aliases = new Map<string, string>();

  bundle.species.forEach((species, index) => {
    const row = index + 2;
    if (!species.id || !species.scientificName) {
      errors.push({ table: "species", row, message: "Species id and scientific name are required." });
    }
    const key = species.scientificName.toLowerCase();
    if (scientific.has(key)) {
      errors.push({ table: "species", row, message: "Duplicate scientific name." });
    }
    scientific.add(key);
    if (!known(SPECIES_STATUSES, species.status)) {
      errors.push({ table: "species", row, message: "Species status is not valid." });
    }
    for (const alias of [species.primaryCommonName, ...species.aliases].filter(Boolean)) {
      const aliasKey = alias.toLowerCase();
      const owner = aliases.get(aliasKey);
      if (owner && owner !== species.id) {
        errors.push({ table: "species", row, message: `Duplicate alias "${alias}".` });
      }
      aliases.set(aliasKey, species.id);
    }
    if (species.status !== "archived") {
      const profile = profilesById.get(species.defaultCareProfileId);
      if (!profile || profile.status !== "published" || profile.speciesId !== species.id) {
        errors.push({
          table: "species",
          row,
          message: "Species needs a default published care profile.",
        });
      }
    }
  });

  bundle.profiles.forEach((profile, index) => {
    const row = index + 2;
    const species = speciesById.get(profile.speciesId);
    if (!species) {
      errors.push({ table: "care_profiles", row, message: "Profile references a missing species." });
    } else if (species.status === "archived") {
      errors.push({ table: "care_profiles", row, message: "Species is archived." });
    }
    if (!known(PROFILE_STATUSES, profile.status)) {
      errors.push({ table: "care_profiles", row, message: "Profile status is not valid." });
    }
    if (!Number.isInteger(profile.version) || profile.version < 1) {
      errors.push({ table: "care_profiles", row, message: "Profile version is required." });
    }
    let applies: Record<string, unknown> = {};
    try {
      const parsed = JSON.parse(profile.appliesToJson) as unknown;
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("shape");
      applies = parsed as Record<string, unknown>;
    } catch {
      errors.push({ table: "care_profiles", row, message: "applies_to_json must be an object." });
    }
    rejectUnknown(errors, "care_profiles", row, stringList(applies.location), LOCATIONS, "location");
    rejectUnknown(
      errors,
      "care_profiles",
      row,
      stringList(applies.growingMethod),
      GROWING_METHODS,
      "growing method",
    );
    rejectUnknown(errors, "care_profiles", row, stringList(applies.lifeStage), LIFE_STAGES, "life stage");
    if (profile.status === "published" || profile.status === "reviewed") {
      if (!profile.reviewedAt || !Number.isFinite(profile.reviewedAt)) {
        errors.push({ table: "care_profiles", row, message: "Review date is required." });
      }
      if (profile.sourceRefs.length === 0) {
        errors.push({ table: "care_profiles", row, message: "A source reference is required." });
      }
    }
    for (const sourceId of profile.sourceRefs) {
      const source = sourcesById.get(sourceId);
      if (!source || !source.name || !source.url || !source.license || !source.retrievedAt) {
        errors.push({
          table: "care_profiles",
          row,
          message: "Source, license, and retrieval date are required.",
        });
      }
    }
  });

  bundle.rules.forEach((rule, index) => {
    const row = index + 2;
    const profile = profilesById.get(rule.careProfileId);
    if (!profile) {
      errors.push({ table: "care_rules", row, message: "Rule references a missing profile." });
    }
    if (!known(TASK_TYPES, rule.taskType)) {
      errors.push({ table: "care_rules", row, message: "Rule task type is not valid." });
    }
    let body: CareRuleJson = {};
    try {
      const parsed = JSON.parse(rule.ruleJson) as unknown;
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("shape");
      body = parsed as CareRuleJson;
    } catch {
      errors.push({ table: "care_rules", row, message: "rule_json must be an object." });
      return;
    }
    if (rule.taskType === "water_check") {
      if (!body.strategy || !known(WATER_STRATEGIES, body.strategy)) {
        errors.push({ table: "care_rules", row, message: "Water rule needs a valid strategy." });
      }
      if (!body.primaryTrigger || !known(WATER_TRIGGERS, body.primaryTrigger)) {
        errors.push({ table: "care_rules", row, message: "Water rule needs a valid trigger." });
      }
      if (
        body.strategy === "condition_based" &&
        body.instructions &&
        FIXED_SCHEDULE.test(body.instructions)
      ) {
        errors.push({
          table: "care_rules",
          row,
          message: "Condition-based water instructions cannot state a fixed schedule.",
        });
      }
    }
    if (typeof body.checkEveryDays === "number") {
      if (!Number.isInteger(body.checkEveryDays) || body.checkEveryDays < 1 || body.checkEveryDays > 365) {
        errors.push({ table: "care_rules", row, message: "checkEveryDays is outside 1 to 365." });
      }
    }
    if (typeof body.dailyHoursMin === "number" && (body.dailyHoursMin < 0 || body.dailyHoursMin > 18)) {
      errors.push({ table: "care_rules", row, message: "dailyHoursMin is outside 0 to 18." });
    }
    for (const key of ["idealCMin", "idealCMax", "minimumC"] as const) {
      const value = body[key];
      if (typeof value === "number" && (value < -40 || value > 50)) {
        errors.push({ table: "care_rules", row, message: `${key} is outside a sensible range.` });
      }
    }
    if (
      typeof body.idealCMin === "number" &&
      typeof body.idealCMax === "number" &&
      body.idealCMin > body.idealCMax
    ) {
      errors.push({ table: "care_rules", row, message: "Ideal temperature minimum exceeds the maximum." });
    }
    const min = zoneRank(body.zoneMin);
    const max = zoneRank(body.zoneMax);
    if (body.zoneMin && min === null) {
      errors.push({ table: "care_rules", row, message: "zoneMin is not a USDA half-zone." });
    }
    if (body.zoneMax && max === null) {
      errors.push({ table: "care_rules", row, message: "zoneMax is not a USDA half-zone." });
    }
    if (min !== null && max !== null && min > max) {
      errors.push({ table: "care_rules", row, message: "zoneMin is warmer than zoneMax." });
    }
    if (body.season && !known(SEASONS, body.season)) {
      errors.push({ table: "care_rules", row, message: "Season is not valid." });
    }
    rejectUnknown(errors, "care_rules", row, stringList(body.level), LIGHT_LEVELS, "light");
    rejectUnknown(errors, "care_rules", row, stringList(body.type), SOIL_TYPES, "soil");
    if (rule.taskType === "fertilize" && body.instructions && DOSAGE.test(body.instructions)) {
      errors.push({ table: "care_rules", row, message: "Fertilizer guidance must stay general." });
    }
    const sensitive =
      PESTICIDE.test(body.instructions ?? "") ||
      "toxicity" in body ||
      "pesticide" in body ||
      "edible" in body;
    if (sensitive && (!profile || !profile.reviewedAt)) {
      errors.push({
        table: "care_rules",
        row,
        message: "Toxicity or pesticide content requires review.",
      });
    }
  });

  bundle.sources.forEach((source, index) => {
    const row = index + 2;
    if (!source.id || !source.name || !source.url || !source.license || !source.retrievedAt) {
      errors.push({
        table: "data_sources",
        row,
        message: "Source, license, and retrieval date are required.",
      });
    }
  });
  return errors;
}

function rejectUnknown(
  errors: CareImportError[],
  table: string,
  row: number,
  values: string[],
  allowed: readonly string[],
  label: string,
) {
  for (const value of values) {
    if (!known(allowed, value)) {
      errors.push({ table, row, message: `${label} "${value}" is not a controlled value.` });
    }
  }
}

function quote(value: string): string {
  return `'${value.replaceAll("'", "''")}'`;
}

/** SQL for published profiles only. Draft rows stay out of the database. */
export function buildCareSql(bundle: CareBundle, at = Date.now()): string {
  const published = new Set(
    bundle.profiles.filter((profile) => profile.status === "published").map((profile) => profile.id),
  );
  const speciesIds = new Set(
    bundle.profiles
      .filter((profile) => published.has(profile.id))
      .map((profile) => profile.speciesId),
  );
  const lines: string[] = ["-- Generated care catalog. Published profiles only."];
  for (const source of bundle.sources) {
    lines.push(
      `INSERT INTO data_sources (id, name, url, license, retrieved_at) VALUES (${quote(source.id)}, ${quote(source.name)}, ${quote(source.url)}, ${quote(source.license)}, ${source.retrievedAt}) ON CONFLICT(id) DO UPDATE SET name = excluded.name, url = excluded.url, license = excluded.license, retrieved_at = excluded.retrieved_at;`,
    );
  }
  for (const species of bundle.species) {
    if (!speciesIds.has(species.id) || species.status === "archived") continue;
    const names = JSON.stringify(
      [species.primaryCommonName, ...species.aliases].filter(Boolean),
    );
    lines.push(
      `INSERT INTO species (id, scientific_name, common_names_json, plant_groups_json, toxicity_json, created_at, updated_at, primary_common_name, default_care_profile_id, status) VALUES (${quote(species.id)}, ${quote(species.scientificName)}, ${quote(names)}, '[]', '{}', ${at}, ${at}, ${quote(species.primaryCommonName)}, ${quote(species.defaultCareProfileId)}, ${quote(species.status)}) ON CONFLICT(id) DO UPDATE SET scientific_name = excluded.scientific_name, primary_common_name = excluded.primary_common_name, default_care_profile_id = excluded.default_care_profile_id, status = excluded.status, common_names_json = excluded.common_names_json, updated_at = excluded.updated_at;`,
    );
  }
  for (const profile of bundle.profiles) {
    if (!published.has(profile.id)) continue;
    lines.push(
      `INSERT INTO care_profiles (id, species_id, name, tasks_json, created_at, updated_at, applies_to_json, status, version, reviewed_at, source_refs_json) VALUES (${quote(profile.id)}, ${quote(profile.speciesId)}, ${quote(profile.name)}, '[]', ${at}, ${at}, ${quote(profile.appliesToJson)}, ${quote(profile.status)}, ${profile.version}, ${profile.reviewedAt ?? "NULL"}, ${quote(JSON.stringify(profile.sourceRefs))}) ON CONFLICT(id) DO UPDATE SET name = excluded.name, applies_to_json = excluded.applies_to_json, status = excluded.status, version = excluded.version, reviewed_at = excluded.reviewed_at, source_refs_json = excluded.source_refs_json, updated_at = excluded.updated_at;`,
    );
  }
  for (const rule of bundle.rules) {
    if (!published.has(rule.careProfileId) || rule.status !== "published") continue;
    lines.push(
      `INSERT INTO care_rules (id, care_profile_id, task_type, rule_json, display_order, status) VALUES (${quote(rule.id)}, ${quote(rule.careProfileId)}, ${quote(rule.taskType)}, ${quote(rule.ruleJson)}, ${rule.displayOrder}, ${quote(rule.status)}) ON CONFLICT(id) DO UPDATE SET task_type = excluded.task_type, rule_json = excluded.rule_json, display_order = excluded.display_order, status = excluded.status;`,
    );
  }
  return `${lines.join("\n")}\n`;
}
