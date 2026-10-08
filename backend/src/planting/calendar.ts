/** Day offsets from the two frost anchors. Dates are computed per garden. */

export const FROST_SOURCE =
  "NOAA NCEI U.S. Climate Normals 1991-2020, 50th percentile of the 32°F freeze.";

export const FROST_LABEL = "30-year averages";

/** Kept wide so a plant that is actually in season is not marked off season. */
export const SEASON_PAD_DAYS = 14;

/** A station farther than this is a different climate, not this garden. */
export const MAX_STATION_KM = 300;

const NON_LEAP_YEAR = 2023;

export type FrostAnchor = "last_spring_frost" | "first_fall_frost";
export type SowingMethod = "start_indoors" | "direct_sow" | "transplant";
export type SowingSeason = "spring" | "summer" | "fall" | "winter";

export type Milestone = {
  method: SowingMethod;
  anchor: FrostAnchor;
  startOffsetDays: number;
  endOffsetDays: number;
};

export type SowingPlan = {
  season: SowingSeason;
  milestones: Milestone[];
};

export type FrostDays = {
  lastSpringDoy: number;
  firstFallDoy: number;
};

export type DatedMilestone = {
  method: SowingMethod;
  start: string;
  end: string;
};

export type DatedPlan = {
  season: SowingSeason;
  milestones: DatedMilestone[];
};

const METHODS = new Set<SowingMethod>(["start_indoors", "direct_sow", "transplant"]);
const SEASONS = new Set<SowingSeason>(["spring", "summer", "fall", "winter"]);
const ANCHORS = new Set<FrostAnchor>(["last_spring_frost", "first_fall_frost"]);

export function parsePlans(raw: string): SowingPlan[] | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  if (!Array.isArray(parsed)) return null;
  const plans: SowingPlan[] = [];
  for (const entry of parsed) {
    if (!entry || typeof entry !== "object") return null;
    const record = entry as Record<string, unknown>;
    if (!SEASONS.has(record.season as SowingSeason)) return null;
    if (!Array.isArray(record.milestones)) return null;
    const milestones: Milestone[] = [];
    for (const item of record.milestones) {
      if (!item || typeof item !== "object") return null;
      const milestone = item as Record<string, unknown>;
      if (!METHODS.has(milestone.method as SowingMethod)) return null;
      if (!ANCHORS.has(milestone.anchor as FrostAnchor)) return null;
      if (!Number.isInteger(milestone.startOffsetDays)) return null;
      if (!Number.isInteger(milestone.endOffsetDays)) return null;
      const start = milestone.startOffsetDays as number;
      const end = milestone.endOffsetDays as number;
      if (end < start) return null;
      milestones.push({
        method: milestone.method as SowingMethod,
        anchor: milestone.anchor as FrostAnchor,
        startOffsetDays: start,
        endOffsetDays: end,
      });
    }
    plans.push({ season: record.season as SowingSeason, milestones });
  }
  return plans;
}

/** Day-of-year on a non-leap calendar, so March 30 stays March 30 in leap years. */
export function monthDayToDoy(month: number, day: number): number | null {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const date = new Date(Date.UTC(NON_LEAP_YEAR, month - 1, day));
  if (date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  const start = Date.UTC(NON_LEAP_YEAR, 0, 1);
  return Math.round((date.getTime() - start) / 86_400_000) + 1;
}

export function doyToMonthDay(doy: number): { month: number; day: number } | null {
  if (!Number.isInteger(doy) || doy < 1 || doy > 365) return null;
  const date = new Date(Date.UTC(NON_LEAP_YEAR, 0, doy));
  return { month: date.getUTCMonth() + 1, day: date.getUTCDate() };
}

export function isoDate(year: number, doy: number): string | null {
  const parts = doyToMonthDay(doy);
  if (!parts) return null;
  const month = String(parts.month).padStart(2, "0");
  const day = String(parts.day).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function utcDay(year: number, month: number, day: number): Date {
  return new Date(Date.UTC(year, month - 1, day));
}

export function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 86_400_000);
}

export function formatIso(date: Date): string {
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  const day = String(date.getUTCDate()).padStart(2, "0");
  return `${date.getUTCFullYear()}-${month}-${day}`;
}

export function parseIsoDay(value: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  const date = utcDay(Number(match[1]), Number(match[2]), Number(match[3]));
  if (formatIso(date) !== value) return null;
  return date;
}

export function haversineKm(
  latitudeA: number,
  longitudeA: number,
  latitudeB: number,
  longitudeB: number,
): number {
  const toRad = (degrees: number) => (degrees * Math.PI) / 180;
  const earthKm = 6371;
  const dLat = toRad(latitudeB - latitudeA);
  const dLon = toRad(longitudeB - longitudeA);
  const latA = toRad(latitudeA);
  const latB = toRad(latitudeB);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(latA) * Math.cos(latB) * Math.sin(dLon / 2) ** 2;
  return 2 * earthKm * Math.asin(Math.min(1, Math.sqrt(a)));
}

export type StationPoint = { latitude: number; longitude: number };

export function nearestStation<T extends StationPoint>(
  stations: T[],
  latitude: number,
  longitude: number,
  maxKm = MAX_STATION_KM,
): T | null {
  let best: T | null = null;
  let bestKm = maxKm;
  for (const station of stations) {
    const km = haversineKm(latitude, longitude, station.latitude, station.longitude);
    if (km <= bestKm) {
      best = station;
      bestKm = km;
    }
  }
  return best;
}

function anchorDate(year: number, frost: FrostDays, anchor: FrostAnchor): Date | null {
  const doy = anchor === "last_spring_frost" ? frost.lastSpringDoy : frost.firstFallDoy;
  const parts = doyToMonthDay(doy);
  if (!parts) return null;
  return utcDay(year, parts.month, parts.day);
}

function windowFor(
  year: number,
  frost: FrostDays,
  milestone: Milestone,
  padDays: number,
): { start: Date; end: Date } | null {
  const anchor = anchorDate(year, frost, milestone.anchor);
  if (!anchor) return null;
  return {
    start: addDays(anchor, milestone.startOffsetDays - padDays),
    end: addDays(anchor, milestone.endOffsetDays + padDays),
  };
}

export function isInSeason(plans: SowingPlan[], frost: FrostDays, today: Date): boolean {
  const day = utcDay(today.getUTCFullYear(), today.getUTCMonth() + 1, today.getUTCDate());
  const years = [day.getUTCFullYear() - 1, day.getUTCFullYear(), day.getUTCFullYear() + 1];
  for (const plan of plans) {
    for (const milestone of plan.milestones) {
      for (const year of years) {
        const window = windowFor(year, frost, milestone, SEASON_PAD_DAYS);
        if (!window) continue;
        if (day >= window.start && day <= window.end) return true;
      }
    }
  }
  return false;
}

export function datedPlans(plans: SowingPlan[], frost: FrostDays, today: Date): DatedPlan[] {
  const day = utcDay(today.getUTCFullYear(), today.getUTCMonth() + 1, today.getUTCDate());
  const years = [
    day.getUTCFullYear() - 1,
    day.getUTCFullYear(),
    day.getUTCFullYear() + 1,
    day.getUTCFullYear() + 2,
  ];
  return plans.map((plan) => ({
    season: plan.season,
    milestones: plan.milestones.flatMap((milestone) => {
      const candidates = years.flatMap((year) => {
        const window = windowFor(year, frost, milestone, 0);
        return window ? [window] : [];
      });
      const upcoming = candidates
        .filter((window) => window.end >= day)
        .sort((a, b) => a.start.getTime() - b.start.getTime());
      const chosen = upcoming[0] ?? candidates[candidates.length - 1];
      if (!chosen) return [];
      return [{ method: milestone.method, start: formatIso(chosen.start), end: formatIso(chosen.end) }];
    }),
  }));
}
