import { Hono } from "hono";
import { z } from "zod";
import { assignCarePlan } from "../catalog/care_plan";
import { LIGHT_LEVELS } from "../catalog/care_rules";
import { careForName, readPlantCare, writePlantCare } from "../catalog/plant_care";
import type { AppEnv } from "../env";
import { parseBody, readObject } from "../http/body";
import { decodeCursor, encodeCursor, pageLimit } from "../http/cursor";
import { ApiError } from "../http/errors";
import { clientId, iso, now, optionalClientId, optionalTime, readJson } from "../http/ids";
import { seedPlantReminders } from "../services/reminders";

export const plantRoutes = new Hono<AppEnv>();

const locationTypes = ["indoor", "outdoor", "greenhouse", "other"] as const;
const healthValues = ["healthy", "needs_attention", "recovering", "unknown"] as const;
const ageStages = ["seed", "seedling", "young_establishing", "mature", "unknown"] as const;
const growingMethods = ["container", "in_ground", "raised_bed", "hydroponic", "other"] as const;

const zoneSchema = z
  .string()
  .trim()
  .regex(/^(?:1[0-3]|[1-9])[ab]$/i)
  .nullable()
  .optional();

const careGuideSchema = z
  .object({
    light: z.string().max(500).nullable().optional(),
    pests: z.string().max(500).nullable().optional(),
    feeding: z.string().max(500).nullable().optional(),
    pruning: z.string().max(500).nullable().optional(),
    humidity: z.string().max(500).nullable().optional(),
    repotting: z.string().max(500).nullable().optional(),
  })
  .strict();

const createSchema = z
  .object({
    id: z.string().optional(),
    gardenId: z.string().min(1),
    speciesId: z.string().min(1).nullable().optional(),
    careProfileId: z.string().min(1).nullable().optional(),
    nickname: z.string().max(120).nullable().optional(),
    locationType: z.enum(locationTypes).nullable().optional(),
    acquiredAt: z.union([z.string(), z.number()]).nullable().optional(),
    plantedAt: z.union([z.string(), z.number()]).nullable().optional(),
    health: z.enum(healthValues).nullable().optional(),
    plantAgeStage: z.enum(ageStages).nullable().optional(),
    notes: z.string().max(4000).nullable().optional(),
    growingMethod: z.enum(growingMethods).nullable().optional(),
    sunlight: z.enum(LIGHT_LEVELS).nullable().optional(),
    hardinessZone: zoneSchema,
  })
  .strict();

const patchSchema = z
  .object({
    gardenId: z.string().min(1).optional(),
    nickname: z.string().max(120).nullable().optional(),
    locationType: z.enum(locationTypes).nullable().optional(),
    health: z.enum(healthValues).nullable().optional(),
    notes: z.string().max(4000).nullable().optional(),
    archivedAt: z.union([z.string(), z.number()]).nullable().optional(),
    scientificName: z.string().max(200).nullable().optional(),
    plantedAt: z.union([z.string(), z.number()]).nullable().optional(),
    ageFrom: z.union([z.string(), z.number()]).nullable().optional(),
    growingMethod: z.enum(growingMethods).nullable().optional(),
    coverPhotoId: z.string().min(1).nullable().optional(),
    careGuide: careGuideSchema.nullable().optional(),
  })
  .strict();

type PlantRow = {
  id: string;
  garden_id: string;
  species_id: string | null;
  nickname: string | null;
  location_type: string | null;
  acquired_at: number | null;
  planted_at: number | null;
  archived_at: number | null;
  last_watered_at: number | null;
  next_water_check_at: number | null;
  last_fertilized_at: number | null;
  next_fertilize_at: number | null;
  last_pest_check_at: number | null;
  next_pest_check_at: number | null;
  health: string | null;
  notes: string | null;
  care_tasks_json: string | null;
  plant_age_stage: string | null;
  revision: number;
  created_at: number;
  updated_at: number;
  plant_scientific_name: string | null;
  growing_method: string | null;
  age_from: number | null;
  cover_photo_id: string | null;
  care_guide_json: string | null;
  care_profile_id: string | null;
  catalog_scientific_name: string | null;
};

function plantJson(row: PlantRow) {
  const care = readPlantCare(row.care_tasks_json);
  return {
    id: row.id,
    gardenId: row.garden_id,
    speciesId: row.species_id,
    speciesName: row.catalog_scientific_name,
    scientificName: row.plant_scientific_name,
    nickname: row.nickname,
    locationType: row.location_type,
    growingMethod: row.growing_method,
    careProfileId: row.care_profile_id,
    ageFrom: iso(row.age_from),
    coverPhotoId: row.cover_photo_id,
    careGuide: careGuideFrom(row.care_guide_json),
    acquiredAt: iso(row.acquired_at),
    plantedAt: iso(row.planted_at),
    archivedAt: iso(row.archived_at),
    lastWateredAt: iso(row.last_watered_at),
    nextWaterCheckAt: iso(row.next_water_check_at),
    lastFertilizedAt: iso(row.last_fertilized_at),
    nextFertilizeAt: iso(row.next_fertilize_at),
    lastPestCheckAt: iso(row.last_pest_check_at),
    nextPestCheckAt: iso(row.next_pest_check_at),
    health: row.health,
    notes: row.notes,
    plantAgeStage: row.plant_age_stage,
    careTasks: care.tasks,
    difficulty: care.difficulty,
    light: care.light,
    sourceUrl: care.sourceUrl,
    sourceLabel: care.sourceLabel,
    revision: row.revision,
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
  };
}

function careResponse(
  care: ReturnType<typeof readPlantCare>,
  speciesId: string | null,
) {
  return {
    careTasks: care.tasks,
    difficulty: care.difficulty,
    light: care.light,
    sourceUrl: care.sourceUrl,
    sourceLabel: care.sourceLabel,
    speciesId,
  };
}

const plantSelect = `
  SELECT p.id, p.garden_id, p.species_id, p.nickname, p.location_type,
    p.acquired_at, p.planted_at, p.archived_at,
    p.last_watered_at, p.next_water_check_at,
    p.last_fertilized_at, p.next_fertilize_at,
    p.last_pest_check_at, p.next_pest_check_at,
    p.health, p.notes, p.care_tasks_json, p.plant_age_stage, p.revision, p.created_at, p.updated_at,
    p.scientific_name AS plant_scientific_name,
    p.growing_method, p.age_from, p.cover_photo_id, p.care_guide_json, p.care_profile_id,
    s.scientific_name AS catalog_scientific_name
  FROM plants p
  LEFT JOIN species s ON s.id = p.species_id
`;

plantRoutes.get("/v1/plants", async (c) => {
  const userId = c.get("userId");
  const limit = pageLimit(c.req.query("limit"));
  const cursor = decodeCursor(c.req.query("cursor"));
  const gardenId = c.req.query("gardenId");
  const updatedAt = cursor?.updatedAt ?? Number.MAX_SAFE_INTEGER;
  const id = cursor?.id ?? "\uffff";
  const rows = await c.env.DB.prepare(
    `${plantSelect}
     WHERE p.user_id = ? AND p.deleted_at IS NULL
       AND (? IS NULL OR p.garden_id = ?)
       AND (p.updated_at < ? OR (p.updated_at = ? AND p.id < ?))
     ORDER BY p.updated_at DESC, p.id DESC
     LIMIT ?`,
  )
    .bind(userId, gardenId ?? null, gardenId ?? null, updatedAt, updatedAt, id, limit + 1)
    .all<PlantRow>();
  const list = rows.results ?? [];
  const page = list.slice(0, limit);
  const last = page[page.length - 1];
  return c.json({
    results: page.map(plantJson),
    nextCursor: list.length > limit && last ? encodeCursor(last.updated_at, last.id) : null,
  });
});

plantRoutes.post("/v1/plants", async (c) => {
  const userId = c.get("userId");
  const body = parseBody(createSchema, await readObject(c));
  const gardenId = clientId(body.gardenId, "gardenId");
  const garden = await c.env.DB.prepare(
    "SELECT id FROM gardens WHERE id = ? AND user_id = ? AND deleted_at IS NULL",
  )
    .bind(gardenId, userId)
    .first();
  if (!garden) throw new ApiError(404, "not_found", "Garden not found.");

  const id = optionalClientId(body.id, "id");
  const ts = now();
  const speciesId = body.speciesId ?? null;
  const plantedAt = optionalTime(body.plantedAt, "plantedAt");
  const inserted = await c.env.DB.prepare(
    `INSERT INTO plants (
      id, user_id, garden_id, species_id, nickname, location_type,
      acquired_at, planted_at, health, notes, plant_age_stage, growing_method,
      revision, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    ON CONFLICT(id) DO NOTHING`,
  )
    .bind(
      id,
      userId,
      gardenId,
      speciesId,
      body.nickname ?? null,
      body.locationType ?? null,
      optionalTime(body.acquiredAt, "acquiredAt"),
      plantedAt,
      body.health ?? null,
      body.notes ?? null,
      body.plantAgeStage ?? null,
      body.growingMethod ?? null,
      ts,
      ts,
    )
    .run();

  const created = await c.env.DB.prepare(
    "SELECT id, user_id FROM plants WHERE id = ? AND deleted_at IS NULL",
  )
    .bind(id)
    .first<{ id: string; user_id: string }>();
  if (!created || created.user_id !== userId) {
    throw new ApiError(409, "conflict", "That id is already in use.");
  }

  if ((inserted.meta.changes ?? 0) > 0) {
    const assigned = await assignCarePlan(c.env.DB, {
      userId,
      plantId: id,
      speciesId,
      locationType: body.locationType ?? null,
      growingMethod: body.growingMethod ?? null,
      sunlight: body.sunlight ?? null,
      hardinessZone: body.hardinessZone ?? null,
      plantedAt,
      plantAgeStage: body.plantAgeStage ?? null,
      at: ts,
    });
    if (assigned.tasks.length > 0) {
      await seedPlantReminders(c.env.DB, {
        userId,
        plantId: id,
        speciesId,
        careProfileId: assigned.profileId,
        tasks: assigned.tasks,
      });
    }
  }

  const row = await loadPlant(c.env.DB, userId, id);
  c.header("ETag", `"${row.revision}"`);
  return c.json(plantJson(row), 201);
});

plantRoutes.post("/v1/plants/:plantId/chores", async (c) => {
  const userId = c.get("userId");
  const plantId = clientId(c.req.param("plantId"), "plantId");
  const row = await loadPlant(c.env.DB, userId, plantId);
  const saved = readPlantCare(row.care_tasks_json);
  if (saved.tasks.length > 0) {
    await seedPlantReminders(c.env.DB, {
      userId,
      plantId,
      speciesId: row.species_id,
      tasks: saved.tasks,
    });
    return c.json({ ok: true });
  }
  if (!row.species_id) {
    throw new ApiError(
      412,
      "failed_precondition",
      "This plant has no care rhythm yet.",
    );
  }
  const profile = await c.env.DB.prepare(
    "SELECT id FROM care_profiles WHERE species_id = ? LIMIT 1",
  )
    .bind(row.species_id)
    .first();
  if (!profile) {
    throw new ApiError(
      412,
      "failed_precondition",
      "This species has no care profile yet.",
    );
  }
  await seedPlantReminders(c.env.DB, {
    userId,
    plantId,
    speciesId: row.species_id,
  });
  return c.json({ ok: true });
});

const careTaskSchema = z.object({
  taskType: z.enum(["water_check", "fertilize", "pest_check"]),
  intervalDays: z.number().int().min(1).max(365),
  instructions: z.string().max(500),
});

plantRoutes.post("/v1/plants/:plantId/care", async (c) => {
  const userId = c.get("userId");
  const plantId = clientId(c.req.param("plantId"), "plantId");
  const row = await loadPlant(c.env.DB, userId, plantId);
  const saved = readPlantCare(row.care_tasks_json);
  if (saved.tasks.length > 0) {
    return c.json(careResponse(saved, row.species_id));
  }
  const found = await careForName(row.nickname ?? "", {
    floraApiKey: c.env.FLORA_API_KEY,
  });
  const ts = now();
  await c.env.DB.prepare(
    `UPDATE plants SET
      care_tasks_json = ?,
      revision = revision + 1,
      updated_at = ?
     WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
  )
    .bind(writePlantCare(found), ts, plantId, userId)
    .run();
  await seedPlantReminders(c.env.DB, {
    userId,
    plantId,
    speciesId: row.species_id,
    tasks: found.tasks,
  });
  return c.json(careResponse(found, row.species_id));
});

plantRoutes.patch("/v1/plants/:plantId/care", async (c) => {
  const userId = c.get("userId");
  const plantId = clientId(c.req.param("plantId"), "plantId");
  const row = await loadPlant(c.env.DB, userId, plantId);
  const body = parseBody(
    z.object({ tasks: z.array(careTaskSchema).min(1).max(3) }).strict(),
    await readObject(c),
  );
  const current = readPlantCare(row.care_tasks_json);
  const tasks = current.tasks.map((task) => {
    const edited = body.tasks.find((item) => item.taskType === task.taskType);
    if (!edited) return task;
    return {
      ...task,
      intervalDays: edited.intervalDays,
      instructions: edited.instructions,
    };
  });
  const ts = now();
  await c.env.DB.prepare(
    `UPDATE plants SET care_tasks_json = ?, revision = revision + 1, updated_at = ?
     WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
  )
    .bind(writePlantCare({ ...current, tasks }), ts, plantId, userId)
    .run();
  for (const task of tasks) {
    await c.env.DB.prepare(
      `UPDATE reminders SET instructions = ?, interval_days = ?, updated_at = ?
       WHERE user_id = ? AND plant_id = ? AND task_type = ? AND status = 'open' AND deleted_at IS NULL`,
    )
      .bind(task.instructions, task.intervalDays, ts, userId, plantId, task.taskType)
      .run();
  }
  const updated = await loadPlant(c.env.DB, userId, plantId);
  c.header("ETag", `"${updated.revision}"`);
  return c.json(plantJson(updated));
});

plantRoutes.get("/v1/plants/:plantId", async (c) => {
  const row = await loadPlant(c.env.DB, c.get("userId"), c.req.param("plantId"));
  c.header("ETag", `"${row.revision}"`);
  return c.json(plantJson(row));
});

plantRoutes.patch("/v1/plants/:plantId", async (c) => {
  const userId = c.get("userId");
  const plantId = clientId(c.req.param("plantId"), "plantId");
  const current = await loadPlant(c.env.DB, userId, plantId);
  const revision = expectedRevision(c.req.header("If-Match"));
  if (revision !== current.revision) {
    throw new ApiError(409, "conflict", "The plant was updated. Refresh and try again.");
  }
  const body = parseBody(patchSchema, await readObject(c));
  if (body.gardenId) {
    const garden = await c.env.DB.prepare(
      "SELECT id FROM gardens WHERE id = ? AND user_id = ? AND deleted_at IS NULL",
    )
      .bind(body.gardenId, userId)
      .first();
    if (!garden) throw new ApiError(404, "not_found", "Garden not found.");
  }
  if (body.coverPhotoId) {
    const photo = await c.env.DB.prepare(
      `SELECT id FROM photos
       WHERE id = ? AND plant_id = ? AND user_id = ? AND deleted_at IS NULL`,
    )
      .bind(body.coverPhotoId, plantId, userId)
      .first();
    if (!photo) throw new ApiError(404, "not_found", "Photo not found.");
  }
  const ts = now();
  const result = await c.env.DB.prepare(
    `UPDATE plants SET
      garden_id = COALESCE(?, garden_id),
      nickname = CASE WHEN ? THEN ? ELSE nickname END,
      location_type = CASE WHEN ? THEN ? ELSE location_type END,
      health = CASE WHEN ? THEN ? ELSE health END,
      notes = CASE WHEN ? THEN ? ELSE notes END,
      archived_at = CASE WHEN ? THEN ? ELSE archived_at END,
      scientific_name = CASE WHEN ? THEN ? ELSE scientific_name END,
      planted_at = CASE WHEN ? THEN ? ELSE planted_at END,
      age_from = CASE WHEN ? THEN ? ELSE age_from END,
      growing_method = CASE WHEN ? THEN ? ELSE growing_method END,
      cover_photo_id = CASE WHEN ? THEN ? ELSE cover_photo_id END,
      care_guide_json = CASE WHEN ? THEN ? ELSE care_guide_json END,
      revision = revision + 1,
      updated_at = ?
     WHERE id = ? AND user_id = ? AND revision = ? AND deleted_at IS NULL`,
  )
    .bind(
      body.gardenId ?? null,
      body.nickname !== undefined ? 1 : 0,
      body.nickname ?? null,
      body.locationType !== undefined ? 1 : 0,
      body.locationType ?? null,
      body.health !== undefined ? 1 : 0,
      body.health ?? null,
      body.notes !== undefined ? 1 : 0,
      body.notes ?? null,
      body.archivedAt !== undefined ? 1 : 0,
      body.archivedAt === undefined ? null : optionalTime(body.archivedAt, "archivedAt"),
      body.scientificName !== undefined ? 1 : 0,
      body.scientificName ?? null,
      body.plantedAt !== undefined ? 1 : 0,
      body.plantedAt === undefined ? null : optionalTime(body.plantedAt, "plantedAt"),
      body.ageFrom !== undefined ? 1 : 0,
      body.ageFrom === undefined ? null : optionalTime(body.ageFrom, "ageFrom"),
      body.growingMethod !== undefined ? 1 : 0,
      body.growingMethod ?? null,
      body.coverPhotoId !== undefined ? 1 : 0,
      body.coverPhotoId ?? null,
      body.careGuide !== undefined ? 1 : 0,
      body.careGuide === undefined || body.careGuide === null
        ? null
        : JSON.stringify(body.careGuide),
      ts,
      plantId,
      userId,
      revision,
    )
    .run();
  if ((result.meta.changes ?? 0) === 0) {
    throw new ApiError(409, "conflict", "The plant was updated. Refresh and try again.");
  }
  const row = await loadPlant(c.env.DB, userId, plantId);
  c.header("ETag", `"${row.revision}"`);
  return c.json(plantJson(row));
});

plantRoutes.delete("/v1/plants/:plantId", async (c) => {
  const userId = c.get("userId");
  const plantId = clientId(c.req.param("plantId"), "plantId");
  await loadPlant(c.env.DB, userId, plantId);
  const ts = now();
  const photos = await c.env.DB.prepare(
    "SELECT object_key FROM photos WHERE plant_id = ? AND user_id = ? AND object_key != ''",
  )
    .bind(plantId, userId)
    .all<{ object_key: string }>();
  await c.env.DB.batch([
    c.env.DB.prepare(
      "UPDATE plants SET deleted_at = ?, updated_at = ?, revision = revision + 1 WHERE id = ? AND user_id = ?",
    ).bind(ts, ts, plantId, userId),
    c.env.DB.prepare(
      "UPDATE reminders SET deleted_at = ?, updated_at = ? WHERE plant_id = ? AND user_id = ? AND deleted_at IS NULL",
    ).bind(ts, ts, plantId, userId),
    c.env.DB.prepare(
      "UPDATE photos SET deleted_at = ? WHERE plant_id = ? AND user_id = ? AND deleted_at IS NULL",
    ).bind(ts, plantId, userId),
    c.env.DB.prepare(
      "UPDATE journal_entries SET deleted_at = ?, updated_at = ? WHERE plant_id = ? AND user_id = ? AND deleted_at IS NULL",
    ).bind(ts, ts, plantId, userId),
  ]);
  for (const photo of photos.results ?? []) {
    await c.env.IMAGES.delete(photo.object_key);
  }
  return c.body(null, 204);
});

export async function loadPlant(db: D1Database, userId: string, plantId: string): Promise<PlantRow> {
  const row = await db
    .prepare(`${plantSelect} WHERE p.id = ? AND p.user_id = ? AND p.deleted_at IS NULL`)
    .bind(plantId, userId)
    .first<PlantRow>();
  if (!row) throw new ApiError(404, "not_found", "Plant not found.");
  return row;
}

function careGuideFrom(raw: string | null) {
  if (!raw) return null;
  const value = readJson<Record<string, unknown>>(raw, {});
  const text = (key: string) => (typeof value[key] === "string" ? value[key] : null);
  return {
    light: text("light"),
    pests: text("pests"),
    feeding: text("feeding"),
    pruning: text("pruning"),
    humidity: text("humidity"),
    repotting: text("repotting"),
  };
}

function expectedRevision(header: string | undefined): number {
  if (!header) {
    throw new ApiError(409, "conflict", "If-Match revision is required.");
  }
  const value = Number(header.replaceAll('"', ""));
  if (!Number.isInteger(value)) {
    throw new ApiError(409, "conflict", "If-Match revision is required.");
  }
  return value;
}
