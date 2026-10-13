/** Controlled values a care rule may use. Instructions are display copy. */

export const LIGHT_LEVELS = [
  "full_sun",
  "partial_sun",
  "partial_shade",
  "full_shade",
  "bright_indirect",
  "low_light",
] as const;

export const WATER_STRATEGIES = [
  "condition_based",
  "interval",
  "weather_based",
  "seasonal",
] as const;

export const WATER_TRIGGERS = [
  "soil_dry",
  "top_soil_dry",
  "root_zone_dry",
  "soil_moist",
] as const;

export const SOIL_TYPES = [
  "succulent_mix",
  "well_draining",
  "loamy",
  "acidic",
  "citrus_mix",
] as const;

export const SEASONS = [
  "spring",
  "summer",
  "fall",
  "winter",
  "dormant",
  "active_growth",
] as const;

export const TASK_TYPES = [
  "water_check",
  "fertilize",
  "prune",
  "repot",
  "pest_check",
  "harvest",
] as const;

export const LOCATIONS = ["indoor", "outdoor", "greenhouse", "other"] as const;
export const GROWING_METHODS = [
  "container",
  "in_ground",
  "raised_bed",
  "hydroponic",
  "other",
] as const;
export const LIFE_STAGES = ["newly_planted", "established"] as const;

export type TaskType = (typeof TASK_TYPES)[number];
export type Season = (typeof SEASONS)[number];
export type LifeStage = (typeof LIFE_STAGES)[number];

const TASK_TITLES: Record<TaskType, string> = {
  water_check: "Check moisture",
  fertilize: "Fertilize",
  prune: "Prune",
  repot: "Repot",
  pest_check: "Check pests",
  harvest: "Harvest",
};

const NINETY_DAYS = 90 * 24 * 60 * 60 * 1000;

export type AppliesTo = {
  location?: string[];
  growingMethod?: string[];
  lifeStage?: string[];
  zoneMin?: string;
  zoneMax?: string;
};

export type CareRuleJson = {
  strategy?: string;
  primaryTrigger?: string;
  checkEveryDays?: number;
  requireDryThroughPot?: boolean;
  instructions?: string;
  season?: string;
  level?: string | string[];
  type?: string | string[];
  zoneMin?: string;
  zoneMax?: string;
  activeGrowthOnly?: boolean;
  idealCMin?: number;
  idealCMax?: number;
  minimumC?: number;
  dailyHoursMin?: number;
  enabled?: boolean;
};

export type CareProfileRecord = {
  id: string;
  name: string;
  appliesTo: AppliesTo;
  status: string;
  version: number;
  tasksJson: string;
};

export type CareRuleRecord = {
  id: string;
  careProfileId: string;
  taskType: string;
  rule: CareRuleJson;
  displayOrder: number;
  status: string;
};

export type PlantCareContext = {
  locationType: string | null;
  growingMethod: string | null;
  sunlight: string | null;
  hardinessZone: string | null;
  newlyPlanted: boolean;
};

export type ZoneResult = "in_range" | "colder" | "warmer";

export type CarePlanItem = {
  taskType: string;
  title: string;
  instruction: string;
  checkEveryDays: number | null;
  strategy: string | null;
  primaryTrigger: string | null;
};

export type CarePlanZone = {
  result: ZoneResult;
  gardenerZone: string;
  zoneMin: string;
  zoneMax: string;
  instruction: string;
};

export type CarePlan = {
  careProfileId: string;
  careProfileVersion: number;
  generatedAt: string;
  zone: CarePlanZone | null;
  items: CarePlanItem[];
};

export function parseAppliesTo(raw: string | null | undefined): AppliesTo {
  if (!raw) return {};
  try {
    const value = JSON.parse(raw) as AppliesTo;
    if (!value || typeof value !== "object" || Array.isArray(value)) return {};
    return value;
  } catch {
    return {};
  }
}

export function parseRuleJson(raw: string | null | undefined): CareRuleJson {
  if (!raw) return {};
  try {
    const value = JSON.parse(raw) as CareRuleJson;
    if (!value || typeof value !== "object" || Array.isArray(value)) return {};
    return value;
  } catch {
    return {};
  }
}

/** Half-zone rank. 8a is 8, 8b is 8.5. Null when the token is not a USDA zone. */
export function zoneRank(zone: string | null | undefined): number | null {
  if (!zone) return null;
  const match = /^(1[0-3]|[1-9])([ab])$/i.exec(zone.trim());
  if (!match) return null;
  return Number(match[1]) + (match[2].toLowerCase() === "b" ? 0.5 : 0);
}

export function normalizeZone(zone: string | null | undefined): string | null {
  if (!zone) return null;
  const rank = zoneRank(zone);
  if (rank === null) return null;
  return zone.trim().toLowerCase();
}

export function seasonOf(at: Date): Season {
  const month = at.getUTCMonth();
  if (month >= 2 && month <= 4) return "spring";
  if (month >= 5 && month <= 7) return "summer";
  if (month >= 8 && month <= 10) return "fall";
  return "winter";
}

export function seasonMatches(ruleSeason: string | undefined, current: Season): boolean {
  if (!ruleSeason) return true;
  if (ruleSeason === current) return true;
  if (ruleSeason === "active_growth") return current === "spring" || current === "summer";
  if (ruleSeason === "dormant") return current === "winter";
  return false;
}

export function isNewlyPlanted(input: {
  plantedAt: number | null;
  plantAgeStage: string | null;
  at: number;
}): boolean {
  if (
    input.plantAgeStage === "seed" ||
    input.plantAgeStage === "seedling" ||
    input.plantAgeStage === "young_establishing"
  ) {
    return true;
  }
  if (input.plantedAt === null) return false;
  const age = input.at - input.plantedAt;
  return age >= 0 && age <= NINETY_DAYS;
}

function listed(value: string[] | undefined): boolean {
  return Array.isArray(value) && value.length > 0;
}

function matches(applies: AppliesTo, context: PlantCareContext): boolean {
  if (
    listed(applies.location) &&
    context.locationType &&
    !applies.location!.includes(context.locationType)
  ) {
    return false;
  }
  if (
    listed(applies.growingMethod) &&
    context.growingMethod &&
    !applies.growingMethod!.includes(context.growingMethod)
  ) {
    return false;
  }
  if (listed(applies.lifeStage)) {
    const stage: LifeStage = context.newlyPlanted ? "newly_planted" : "established";
    if (!applies.lifeStage!.includes(stage)) return false;
  }
  return true;
}

function specificity(applies: AppliesTo): number {
  let score = 0;
  if (listed(applies.location)) score += 1;
  if (listed(applies.growingMethod)) score += 1;
  if (listed(applies.lifeStage)) score += 1;
  return score;
}

/** Most specific published profile. Falls back to the species default. */
export function selectCareProfile(
  profiles: CareProfileRecord[],
  context: PlantCareContext,
  defaultProfileId: string | null,
): CareProfileRecord | null {
  const published = profiles.filter((profile) => profile.status === "published");
  const matched = published.filter((profile) => matches(profile.appliesTo, context));
  matched.sort((a, b) => {
    const score = specificity(b.appliesTo) - specificity(a.appliesTo);
    if (score !== 0) return score;
    if (a.id === defaultProfileId) return -1;
    if (b.id === defaultProfileId) return 1;
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });
  if (matched[0]) return matched[0];
  return published.find((profile) => profile.id === defaultProfileId) ?? null;
}

function ruleSeason(rule: CareRuleJson): string | undefined {
  return typeof rule.season === "string" ? rule.season : undefined;
}

/** One published rule per task. A seasonal rule wins over a general one. */
export function applicableRules(rules: CareRuleRecord[], at: Date): CareRuleRecord[] {
  const season = seasonOf(at);
  const byTask = new Map<string, CareRuleRecord[]>();
  for (const rule of rules) {
    if (rule.status !== "published") continue;
    const list = byTask.get(rule.taskType) ?? [];
    list.push(rule);
    byTask.set(rule.taskType, list);
  }
  const chosen: CareRuleRecord[] = [];
  for (const list of byTask.values()) {
    const matching = list.filter((rule) => seasonMatches(ruleSeason(rule.rule), season));
    const seasonal = matching.filter((rule) => ruleSeason(rule.rule));
    const pool = (seasonal.length > 0 ? seasonal : matching.filter((rule) => !ruleSeason(rule.rule)))
      .slice()
      .sort((a, b) => a.displayOrder - b.displayOrder);
    if (pool[0]) chosen.push(pool[0]);
  }
  chosen.sort((a, b) => a.displayOrder - b.displayOrder);
  return chosen;
}

function daysLabel(days: number): string {
  return days === 1 ? "1 day" : `${days} days`;
}

export function waterInstruction(rule: CareRuleJson): string {
  const authored = rule.instructions?.trim();
  if (authored) return authored;
  const days = rule.checkEveryDays;
  const again =
    typeof days === "number" ? ` Check again in about ${daysLabel(days)}.` : "";
  if (rule.strategy === "condition_based" && rule.primaryTrigger === "soil_dry") {
    return `Check that the potting mix has dried fully; water thoroughly only if dry.${again}`;
  }
  if (rule.strategy === "condition_based" && rule.primaryTrigger === "top_soil_dry") {
    return `Water when the top of the soil is dry.${again}`;
  }
  if (rule.strategy === "condition_based" && rule.primaryTrigger === "root_zone_dry") {
    return `Water when the root zone has dried.${again}`;
  }
  if (rule.strategy === "condition_based" && rule.primaryTrigger === "soil_moist") {
    return `Keep the soil moist, and check before watering again.${again}`;
  }
  if (rule.strategy === "interval" && typeof days === "number") {
    return `Check every ${daysLabel(days)}.`;
  }
  if (rule.strategy === "seasonal") return `Follow the seasonal moisture check.${again}`;
  if (rule.strategy === "weather_based") return `Check moisture and adjust for the weather.${again}`;
  return again.trim();
}

function taskInstruction(taskType: string, rule: CareRuleJson): string {
  if (taskType === "water_check") return waterInstruction(rule);
  const authored = rule.instructions?.trim();
  if (authored) return authored;
  const days = rule.checkEveryDays;
  if (taskType === "fertilize" && rule.activeGrowthOnly && typeof days === "number") {
    return `Fertilize during active growth. Check again in about ${daysLabel(days)}.`;
  }
  if (typeof days === "number") return `Check again in about ${daysLabel(days)}.`;
  return "";
}

export function zoneBounds(
  profile: CareProfileRecord,
  rules: CareRuleRecord[],
): { zoneMin: string | null; zoneMax: string | null } {
  for (const rule of rules) {
    if (rule.status !== "published") continue;
    const zoneMin = normalizeZone(rule.rule.zoneMin);
    const zoneMax = normalizeZone(rule.rule.zoneMax);
    if (zoneMin && zoneMax) return { zoneMin, zoneMax };
  }
  return {
    zoneMin: normalizeZone(profile.appliesTo.zoneMin),
    zoneMax: normalizeZone(profile.appliesTo.zoneMax),
  };
}

export function zoneWarning(input: {
  outdoor: boolean;
  gardenerZone: string | null;
  zoneMin: string | null;
  zoneMax: string | null;
}): CarePlanZone | null {
  if (!input.outdoor) return null;
  const gardenerZone = normalizeZone(input.gardenerZone);
  const zoneMin = normalizeZone(input.zoneMin);
  const zoneMax = normalizeZone(input.zoneMax);
  if (!gardenerZone || !zoneMin || !zoneMax) return null;
  const gardener = zoneRank(gardenerZone)!;
  const min = zoneRank(zoneMin)!;
  const max = zoneRank(zoneMax)!;
  if (gardener < min) {
    return {
      result: "colder",
      gardenerZone,
      zoneMin,
      zoneMax,
      instruction: `Not hardy outdoors in zone ${gardenerZone}. Grow it as a summer plant or keep it inside.`,
    };
  }
  if (gardener > max) {
    return {
      result: "warmer",
      gardenerZone,
      zoneMin,
      zoneMax,
      instruction: "Your zone is warmer than this plant prefers outdoors.",
    };
  }
  return {
    result: "in_range",
    gardenerZone,
    zoneMin,
    zoneMax,
    instruction: `Grows outdoors in your zone (${gardenerZone}).`,
  };
}

type StoredTask = {
  taskType?: string;
  title?: string;
  intervalDays?: number;
  instructions?: string;
};

function itemsFromTasks(raw: string): CarePlanItem[] {
  let tasks: StoredTask[] = [];
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (Array.isArray(parsed)) tasks = parsed as StoredTask[];
  } catch {
    tasks = [];
  }
  return tasks
    .filter((task) => typeof task.taskType === "string" && task.taskType)
    .map((task) => ({
      taskType: task.taskType!,
      title: task.title?.trim() || task.taskType!,
      instruction: task.instructions?.trim() || "",
      checkEveryDays: typeof task.intervalDays === "number" ? task.intervalDays : null,
      strategy: null,
      primaryTrigger: null,
    }));
}

export function renderCarePlan(input: {
  profile: CareProfileRecord;
  rules: CareRuleRecord[];
  context: PlantCareContext;
  at: Date;
}): CarePlan {
  const rules = input.rules.filter((rule) => rule.careProfileId === input.profile.id);
  const chosen = applicableRules(rules, input.at);
  const items =
    chosen.length > 0
      ? chosen.map((rule) => {
          const known = TASK_TYPES.find((task) => task === rule.taskType);
          return {
            taskType: rule.taskType,
            title: known ? TASK_TITLES[known] : rule.taskType,
            instruction: taskInstruction(rule.taskType, rule.rule),
            checkEveryDays:
              typeof rule.rule.checkEveryDays === "number" ? rule.rule.checkEveryDays : null,
            strategy: rule.rule.strategy ?? null,
            primaryTrigger: rule.rule.primaryTrigger ?? null,
          };
        })
      : itemsFromTasks(input.profile.tasksJson);
  const bounds = zoneBounds(input.profile, rules);
  return {
    careProfileId: input.profile.id,
    careProfileVersion: input.profile.version,
    generatedAt: input.at.toISOString(),
    zone: zoneWarning({
      outdoor: input.context.locationType === "outdoor",
      gardenerZone: input.context.hardinessZone,
      zoneMin: bounds.zoneMin,
      zoneMax: bounds.zoneMax,
    }),
    items: items.filter((item) => item.instruction || item.checkEveryDays),
  };
}
