import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { ApiError } from "../http/errors";
import {
  FROST_LABEL,
  FROST_SOURCE,
  datedPlans,
  isInSeason,
  isoDate,
  nearestStation,
  parsePlans,
  type FrostDays,
  type SowingPlan,
} from "../planting/calendar";

export const plantingRoutes = new Hono<AppEnv>();

const point = z.object({
  lat: z.coerce.number().gte(-90).lte(90),
  lon: z.coerce.number().gte(-180).lte(180),
});

type ScheduleRow = {
  id: string;
  species_id: string | null;
  scientific_name: string;
  common_name: string;
  match_names_json: string;
  days_to_harvest: number | null;
  overwinters: number;
  windows_json: string;
};

type LoadedSchedule = ScheduleRow & {
  names: string[];
  plans: SowingPlan[];
};

function todayUtc(): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

function readPoint(c: { req: { query: (name: string) => string | undefined } }) {
  const parsed = point.safeParse({
    lat: c.req.query("lat"),
    lon: c.req.query("lon"),
  });
  if (!parsed.success) {
    throw new ApiError(400, "validation_error", "Latitude and longitude are required.");
  }
  return parsed.data;
}

async function loadSchedules(db: D1Database): Promise<LoadedSchedule[]> {
  const listed = await db.prepare("SELECT * FROM planting_schedules").all<ScheduleRow>();
  const loaded: LoadedSchedule[] = [];
  for (const row of listed.results ?? []) {
    const plans = parsePlans(row.windows_json);
    if (!plans) continue;
    let aliases: string[] = [];
    try {
      const parsed = JSON.parse(row.match_names_json);
      if (Array.isArray(parsed)) {
        aliases = parsed.filter((name): name is string => typeof name === "string");
      }
    } catch {
      aliases = [];
    }
    const names = [row.scientific_name, row.common_name, ...aliases]
      .map((name) => name.trim().toLowerCase())
      .filter((name) => name.length > 0);
    loaded.push({ ...row, names, plans });
  }
  return loaded;
}

function matches(schedule: LoadedSchedule, query: string): boolean {
  const needle = query.trim().toLowerCase();
  if (!needle) return false;
  if (schedule.names.includes(needle)) return true;
  const scientific = schedule.scientific_name.trim().toLowerCase();
  return needle.startsWith(`${scientific} `);
}

async function frostFor(db: D1Database, latitude: number, longitude: number) {
  const span = 3;
  const listed = await db
    .prepare(
      `SELECT id, latitude, longitude, last_spring_doy, first_fall_doy
       FROM frost_stations
       WHERE latitude BETWEEN ? AND ?
         AND longitude BETWEEN ? AND ?`,
    )
    .bind(latitude - span, latitude + span, longitude - span, longitude + span)
    .all<{
      id: string;
      latitude: number;
      longitude: number;
      last_spring_doy: number;
      first_fall_doy: number;
    }>();
  const station = nearestStation(listed.results ?? [], latitude, longitude);
  if (!station) {
    throw new ApiError(
      404,
      "not_found",
      "The frost calendar is not available for this garden.",
    );
  }
  const year = todayUtc().getUTCFullYear();
  const lastSpringFrost = isoDate(year, station.last_spring_doy);
  const firstFallFrost = isoDate(year, station.first_fall_doy);
  if (!lastSpringFrost || !firstFallFrost) {
    throw new ApiError(404, "not_found", "The frost calendar is not available for this garden.");
  }
  const frost: FrostDays = {
    lastSpringDoy: station.last_spring_doy,
    firstFallDoy: station.first_fall_doy,
  };
  return { station, frost, lastSpringFrost, firstFallFrost };
}

plantingRoutes.get("/v1/planting/frost", async (c) => {
  const { lat, lon } = readPoint(c);
  const { station, lastSpringFrost, firstFallFrost } = await frostFor(c.env.DB, lat, lon);
  return c.json({
    lastSpringFrost,
    firstFallFrost,
    stationId: station.id,
    source: FROST_SOURCE,
    label: FROST_LABEL,
  });
});

plantingRoutes.get("/v1/planting/species", async (c) => {
  const { lat, lon } = readPoint(c);
  const name = (c.req.query("name") ?? "").trim();
  const common = (c.req.query("common") ?? "").trim();
  if (name.length < 2 || name.length > 160) {
    throw new ApiError(400, "validation_error", "A plant name is required.");
  }
  const { frost } = await frostFor(c.env.DB, lat, lon);
  const schedules = await loadSchedules(c.env.DB);
  const hits = schedules.filter((schedule) => matches(schedule, name));
  const commonNeedle = common.toLowerCase();
  const byCommon = commonNeedle
    ? hits.filter((schedule) => {
        if (schedule.names.includes(commonNeedle)) return true;
        const label = schedule.common_name.trim().toLowerCase();
        return label.length > 3 && (commonNeedle.includes(label) || label.includes(commonNeedle));
      })
    : [];
  const chosen = byCommon[0] ?? (hits.length === 1 ? hits[0] : null);
  if (!chosen) {
    throw new ApiError(404, "not_found", "This plant has no sowing calendar.");
  }
  return c.json({
    id: chosen.id,
    scientificName: chosen.scientific_name,
    commonName: chosen.common_name,
    daysToHarvest: chosen.days_to_harvest,
    plans: datedPlans(chosen.plans, frost, todayUtc()),
  });
});

plantingRoutes.get("/v1/planting/season", async (c) => {
  const { lat, lon } = readPoint(c);
  const names = (c.req.query("names") ?? "")
    .split(",")
    .map((name) => name.trim())
    .filter((name) => name.length > 0)
    .slice(0, 20);
  if (names.length === 0 || names.some((name) => name.length > 160)) {
    throw new ApiError(400, "validation_error", "At least one plant name is required.");
  }
  const { frost } = await frostFor(c.env.DB, lat, lon);
  const schedules = await loadSchedules(c.env.DB);
  const today = todayUtc();
  return c.json({
    results: names.map((name) => {
      const hits = schedules.filter((schedule) => matches(schedule, name));
      if (hits.length === 0) return { name, inSeason: null };
      const inSeason = hits.some((schedule) => isInSeason(schedule.plans, frost, today));
      return { name, inSeason };
    }),
  });
});
