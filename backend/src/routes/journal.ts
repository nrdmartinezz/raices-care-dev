import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { parseBody, readObject } from "../http/body";
import { ApiError } from "../http/errors";
import { clientId, iso, now, optionalClientId, optionalTime, parseTime } from "../http/ids";
import { loadPlant } from "./plants";

export const journalRoutes = new Hono<AppEnv>();

const noteSchema = z.string().trim().min(1).max(5000);

const createSchema = z
  .object({
    id: z.string().optional(),
    note: noteSchema,
    observedAt: z.union([z.string(), z.number()]).optional(),
  })
  .strict();

const patchSchema = z
  .object({
    note: noteSchema.optional(),
    observedAt: z.union([z.string(), z.number()]).optional(),
  })
  .strict();

type JournalRow = {
  id: string;
  plant_id: string;
  note: string;
  observed_at: number;
  created_at: number;
  updated_at: number;
};

function journalJson(row: JournalRow) {
  return {
    id: row.id,
    plantId: row.plant_id,
    note: row.note,
    observedAt: iso(row.observed_at),
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
  };
}

journalRoutes.get("/v1/plants/:plantId/journal", async (c) => {
  const userId = c.get("userId");
  const plantId = c.req.param("plantId");
  await loadPlant(c.env.DB, userId, plantId);
  const rows = await c.env.DB.prepare(
    `SELECT id, plant_id, note, observed_at, created_at, updated_at
     FROM journal_entries
     WHERE user_id = ? AND plant_id = ? AND deleted_at IS NULL
     ORDER BY observed_at DESC, id DESC
     LIMIT 100`,
  )
    .bind(userId, plantId)
    .all<JournalRow>();
  return c.json({ results: (rows.results ?? []).map(journalJson) });
});

journalRoutes.post("/v1/plants/:plantId/journal", async (c) => {
  const userId = c.get("userId");
  const plantId = clientId(c.req.param("plantId"), "plantId");
  await loadPlant(c.env.DB, userId, plantId);
  const body = parseBody(createSchema, await readObject(c));
  const id = optionalClientId(body.id, "id");
  const ts = now();
  const observedAt = optionalTime(body.observedAt, "observedAt") ?? ts;
  await c.env.DB.prepare(
    `INSERT INTO journal_entries (
      id, user_id, plant_id, note, observed_at, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO NOTHING`,
  )
    .bind(id, userId, plantId, body.note, observedAt, ts, ts)
    .run();
  const row = await c.env.DB.prepare(
    `SELECT id, plant_id, note, observed_at, created_at, updated_at
     FROM journal_entries WHERE id = ? AND deleted_at IS NULL`,
  )
    .bind(id)
    .first<JournalRow & { user_id?: string }>();
  const owner = await c.env.DB.prepare(
    "SELECT user_id FROM journal_entries WHERE id = ?",
  )
    .bind(id)
    .first<{ user_id: string }>();
  if (!row || owner?.user_id !== userId) {
    throw new ApiError(409, "conflict", "That id is already in use.");
  }
  return c.json(journalJson(row), 201);
});

journalRoutes.patch("/v1/plants/:plantId/journal/:entryId", async (c) => {
  const userId = c.get("userId");
  const plantId = c.req.param("plantId");
  await loadPlant(c.env.DB, userId, plantId);
  const body = parseBody(patchSchema, await readObject(c));
  if (body.note === undefined && body.observedAt === undefined) {
    throw new ApiError(400, "validation_error", "Nothing to update.");
  }
  const ts = now();
  const observedAt =
    body.observedAt === undefined ? null : parseTime(body.observedAt, "observedAt");
  const result = await c.env.DB.prepare(
    `UPDATE journal_entries SET
      note = CASE WHEN ? THEN ? ELSE note END,
      observed_at = CASE WHEN ? THEN ? ELSE observed_at END,
      updated_at = ?
     WHERE id = ? AND plant_id = ? AND user_id = ? AND deleted_at IS NULL`,
  )
    .bind(
      body.note !== undefined ? 1 : 0,
      body.note ?? null,
      body.observedAt !== undefined ? 1 : 0,
      observedAt,
      ts,
      c.req.param("entryId"),
      plantId,
      userId,
    )
    .run();
  if ((result.meta.changes ?? 0) === 0) {
    throw new ApiError(404, "not_found", "Note not found.");
  }
  const row = await c.env.DB.prepare(
    `SELECT id, plant_id, note, observed_at, created_at, updated_at
     FROM journal_entries WHERE id = ?`,
  )
    .bind(c.req.param("entryId"))
    .first<JournalRow>();
  if (!row) throw new ApiError(404, "not_found", "Note not found.");
  return c.json(journalJson(row));
});

journalRoutes.delete("/v1/plants/:plantId/journal/:entryId", async (c) => {
  const userId = c.get("userId");
  const plantId = c.req.param("plantId");
  await loadPlant(c.env.DB, userId, plantId);
  const result = await c.env.DB.prepare(
    `UPDATE journal_entries SET deleted_at = ?, updated_at = ?
     WHERE id = ? AND plant_id = ? AND user_id = ? AND deleted_at IS NULL`,
  )
    .bind(now(), now(), c.req.param("entryId"), plantId, userId)
    .run();
  if ((result.meta.changes ?? 0) === 0) {
    throw new ApiError(404, "not_found", "Note not found.");
  }
  return c.body(null, 204);
});
