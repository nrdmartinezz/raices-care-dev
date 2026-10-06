import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { parseBody, readObject } from "../http/body";
import { decodeCursor, encodeCursor, pageLimit } from "../http/cursor";
import { ApiError } from "../http/errors";
import { clientId, iso, now, optionalClientId } from "../http/ids";

export const gardenRoutes = new Hono<AppEnv>();

const gardenSchema = z
  .object({
    id: z.string().optional(),
    name: z.string().min(1).max(120),
    timezone: z.string().max(80).nullable().optional(),
    latitude: z.number().gte(-90).lte(90).nullable().optional(),
    longitude: z.number().gte(-180).lte(180).nullable().optional(),
  })
  .strict();

const gardenPatchSchema = gardenSchema.partial().omit({ id: true });

type GardenRow = {
  id: string;
  name: string;
  timezone: string | null;
  latitude: number | null;
  longitude: number | null;
  created_at: number;
  updated_at: number;
};

function gardenJson(row: GardenRow) {
  return {
    id: row.id,
    name: row.name,
    timezone: row.timezone,
    latitude: row.latitude,
    longitude: row.longitude,
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
  };
}

async function ensureUser(db: D1Database, userId: string) {
  const ts = now();
  await db
    .prepare("INSERT INTO users (id, created_at, updated_at) VALUES (?, ?, ?) ON CONFLICT(id) DO NOTHING")
    .bind(userId, ts, ts)
    .run();
}

gardenRoutes.get("/v1/gardens", async (c) => {
  const userId = c.get("userId");
  const limit = pageLimit(c.req.query("limit"));
  const cursor = decodeCursor(c.req.query("cursor"));
  const updatedAt = cursor?.updatedAt ?? Number.MAX_SAFE_INTEGER;
  const id = cursor?.id ?? "\uffff";
  const rows = await c.env.DB.prepare(
    `SELECT id, name, timezone, latitude, longitude, created_at, updated_at
     FROM gardens
     WHERE user_id = ? AND deleted_at IS NULL
       AND (updated_at < ? OR (updated_at = ? AND id < ?))
     ORDER BY updated_at DESC, id DESC
     LIMIT ?`,
  )
    .bind(userId, updatedAt, updatedAt, id, limit + 1)
    .all<GardenRow>();
  const list = rows.results ?? [];
  const page = list.slice(0, limit);
  const last = page[page.length - 1];
  return c.json({
    results: page.map(gardenJson),
    nextCursor: list.length > limit && last ? encodeCursor(last.updated_at, last.id) : null,
  });
});

gardenRoutes.post("/v1/gardens", async (c) => {
  const userId = c.get("userId");
  const body = parseBody(gardenSchema, await readObject(c));
  const id = optionalClientId(body.id, "id");
  const ts = now();
  await ensureUser(c.env.DB, userId);
  await c.env.DB.prepare(
    `INSERT INTO gardens (id, user_id, name, timezone, latitude, longitude, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO NOTHING`,
  )
    .bind(id, userId, body.name, body.timezone ?? null, body.latitude ?? null, body.longitude ?? null, ts, ts)
    .run();
  const row = await c.env.DB.prepare(
    `SELECT id, name, timezone, latitude, longitude, created_at, updated_at
     FROM gardens WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
  )
    .bind(id, userId)
    .first<GardenRow>();
  if (!row) throw new ApiError(409, "conflict", "That id is already in use.");
  return c.json(gardenJson(row), 201);
});

gardenRoutes.get("/v1/gardens/:gardenId", async (c) => {
  const row = await loadGarden(c.env.DB, c.get("userId"), c.req.param("gardenId"));
  return c.json(gardenJson(row));
});

gardenRoutes.patch("/v1/gardens/:gardenId", async (c) => {
  const userId = c.get("userId");
  const gardenId = clientId(c.req.param("gardenId"), "gardenId");
  await loadGarden(c.env.DB, userId, gardenId);
  const body = parseBody(gardenPatchSchema, await readObject(c));
  const ts = now();
  await c.env.DB.prepare(
    `UPDATE gardens SET
      name = COALESCE(?, name),
      timezone = COALESCE(?, timezone),
      latitude = COALESCE(?, latitude),
      longitude = COALESCE(?, longitude),
      updated_at = ?
     WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
  )
    .bind(
      body.name ?? null,
      body.timezone === undefined ? null : body.timezone,
      body.latitude === undefined ? null : body.latitude,
      body.longitude === undefined ? null : body.longitude,
      ts,
      gardenId,
      userId,
    )
    .run();
  const row = await loadGarden(c.env.DB, userId, gardenId);
  return c.json(gardenJson(row));
});

gardenRoutes.delete("/v1/gardens/:gardenId", async (c) => {
  const userId = c.get("userId");
  const gardenId = clientId(c.req.param("gardenId"), "gardenId");
  await loadGarden(c.env.DB, userId, gardenId);
  const ts = now();
  await c.env.DB.prepare(
    "UPDATE gardens SET deleted_at = ?, updated_at = ? WHERE id = ? AND user_id = ?",
  )
    .bind(ts, ts, gardenId, userId)
    .run();
  return c.body(null, 204);
});

async function loadGarden(db: D1Database, userId: string, gardenId: string): Promise<GardenRow> {
  const row = await db
    .prepare(
      `SELECT id, name, timezone, latitude, longitude, created_at, updated_at
       FROM gardens WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
    )
    .bind(gardenId, userId)
    .first<GardenRow>();
  if (!row) throw new ApiError(404, "not_found", "Garden not found.");
  return row;
}
