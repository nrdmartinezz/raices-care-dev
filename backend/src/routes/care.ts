import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { parseBody, readObject } from "../http/body";
import { pageLimit } from "../http/cursor";
import { ApiError } from "../http/errors";
import { clientId, iso, now, optionalClientId, parseTime, readJson } from "../http/ids";
import { applyCareEvent } from "../services/reminders";
import { loadPlant } from "./plants";

export const careRoutes = new Hono<AppEnv>();

const eventTypes = [
  "watered",
  "fertilized",
  "pruned",
  "repotted",
  "transplanted",
  "harvested",
  "deadheaded",
  "mulched",
  "pest_inspection",
  "pest_treatment",
  "disease_observation",
  "weather_damage",
  "photo_added",
  "health_check",
  "planted",
  "acquired",
  "archived",
] as const;

const createSchema = z
  .object({
    id: z.string().optional(),
    eventType: z.enum(eventTypes),
    occurredAt: z.union([z.string(), z.number()]),
    note: z.string().max(4000).nullable().optional(),
    details: z.record(z.unknown()).optional(),
  })
  .strict();

careRoutes.get("/v1/plants/:plantId/care-events", async (c) => {
  const userId = c.get("userId");
  const plantId = c.req.param("plantId");
  await loadPlant(c.env.DB, userId, plantId);
  const limit = pageLimit(c.req.query("limit"));
  const rows = await c.env.DB.prepare(
    `SELECT id, event_type, occurred_at, note, details_json, created_at
     FROM care_events
     WHERE user_id = ? AND plant_id = ? AND deleted_at IS NULL
     ORDER BY occurred_at DESC, id DESC
     LIMIT ?`,
  )
    .bind(userId, plantId, limit)
    .all<{
      id: string;
      event_type: string;
      occurred_at: number;
      note: string | null;
      details_json: string;
      created_at: number;
    }>();
  return c.json({
    results: (rows.results ?? []).map((row) => ({
      id: row.id,
      plantId,
      eventType: row.event_type,
      occurredAt: iso(row.occurred_at),
      note: row.note,
      details: readJson(row.details_json, {}),
      createdAt: iso(row.created_at),
    })),
  });
});

careRoutes.post("/v1/plants/:plantId/care-events", async (c) => {
  const userId = c.get("userId");
  const plantId = clientId(c.req.param("plantId"), "plantId");
  await loadPlant(c.env.DB, userId, plantId);
  const body = parseBody(createSchema, await readObject(c));
  const id = optionalClientId(body.id, "id");
  const occurredAt = parseTime(body.occurredAt, "occurredAt");
  const ts = now();
  await c.env.DB.prepare(
    `INSERT INTO care_events (
      id, user_id, plant_id, event_type, occurred_at, note, details_json, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO NOTHING`,
  )
    .bind(id, userId, plantId, body.eventType, occurredAt, body.note ?? null, JSON.stringify(body.details ?? {}), ts)
    .run();
  const row = await c.env.DB.prepare(
    "SELECT id, user_id, plant_id FROM care_events WHERE id = ?",
  )
    .bind(id)
    .first<{ id: string; user_id: string; plant_id: string }>();
  if (!row || row.user_id !== userId) {
    throw new ApiError(409, "conflict", "That id is already in use.");
  }
  await applyCareEvent(c.env.DB, {
    userId,
    plantId,
    eventType: body.eventType,
    occurredAt,
  });
  return c.json(
    {
      id,
      plantId,
      eventType: body.eventType,
      occurredAt: iso(occurredAt),
      note: body.note ?? null,
      details: body.details ?? {},
      createdAt: iso(ts),
    },
    201,
  );
});

careRoutes.delete("/v1/plants/:plantId/care-events/:eventId", async (c) => {
  const userId = c.get("userId");
  const plantId = c.req.param("plantId");
  await loadPlant(c.env.DB, userId, plantId);
  const result = await c.env.DB.prepare(
    `UPDATE care_events SET deleted_at = ?
     WHERE id = ? AND plant_id = ? AND user_id = ? AND deleted_at IS NULL`,
  )
    .bind(now(), c.req.param("eventId"), plantId, userId)
    .run();
  if ((result.meta.changes ?? 0) === 0) {
    throw new ApiError(404, "not_found", "Care event not found.");
  }
  return c.body(null, 204);
});
