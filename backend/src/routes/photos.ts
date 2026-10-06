import { Hono } from "hono";
import type { AppEnv } from "../env";
import { ApiError } from "../http/errors";
import { clientId, iso, now } from "../http/ids";
import { plantPhotoKey, readImageBody, sniffImage } from "../services/photos";
import { loadPlant } from "./plants";

export const photoRoutes = new Hono<AppEnv>();

photoRoutes.get("/v1/plants/:plantId/photos", async (c) => {
  const userId = c.get("userId");
  const plantId = c.req.param("plantId");
  await loadPlant(c.env.DB, userId, plantId);
  const rows = await c.env.DB.prepare(
    `SELECT id, content_type, byte_size, created_at FROM photos
     WHERE user_id = ? AND plant_id = ? AND deleted_at IS NULL
     ORDER BY created_at DESC`,
  )
    .bind(userId, plantId)
    .all<{ id: string; content_type: string; byte_size: number; created_at: number }>();
  return c.json({
    results: (rows.results ?? []).map((row) => ({
      id: row.id,
      plantId,
      contentType: row.content_type,
      byteSize: row.byte_size,
      createdAt: iso(row.created_at),
    })),
  });
});

photoRoutes.post("/v1/plants/:plantId/photos", async (c) => {
  const userId = c.get("userId");
  const plantId = clientId(c.req.param("plantId"), "plantId");
  await loadPlant(c.env.DB, userId, plantId);
  const bytes = await readImageBody(c.req.raw);
  const sniffed = sniffImage(bytes);
  const id = crypto.randomUUID();
  const key = plantPhotoKey(userId, plantId, id, sniffed.extension);
  await c.env.IMAGES.put(key, bytes, {
    httpMetadata: { contentType: sniffed.contentType },
  });
  try {
    const ts = now();
    await c.env.DB.prepare(
      `INSERT INTO photos (id, user_id, plant_id, object_key, content_type, byte_size, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(id, userId, plantId, key, sniffed.contentType, bytes.byteLength, ts)
      .run();
    return c.json(
      {
        id,
        plantId,
        contentType: sniffed.contentType,
        byteSize: bytes.byteLength,
        createdAt: iso(ts),
      },
      201,
    );
  } catch (error) {
    await c.env.IMAGES.delete(key);
    throw error;
  }
});

photoRoutes.get("/v1/photos/:photoId", async (c) => {
  const row = await loadPhoto(c.env.DB, c.get("userId"), c.req.param("photoId"));
  const object = await c.env.IMAGES.get(row.object_key);
  if (!object) throw new ApiError(404, "not_found", "Photo not found.");
  return new Response(object.body, {
    headers: {
      "content-type": row.content_type,
      "cache-control": "private, max-age=300",
    },
  });
});

photoRoutes.delete("/v1/photos/:photoId", async (c) => {
  const userId = c.get("userId");
  const photoId = c.req.param("photoId");
  const row = await loadPhoto(c.env.DB, userId, photoId);
  const ts = now();
  await c.env.IMAGES.delete(row.object_key);
  await c.env.DB.prepare(
    "UPDATE photos SET deleted_at = ?, object_key = '' WHERE id = ? AND user_id = ?",
  )
    .bind(ts, photoId, userId)
    .run();
  return c.body(null, 204);
});

async function loadPhoto(db: D1Database, userId: string, photoId: string) {
  const row = await db
    .prepare(
      `SELECT id, object_key, content_type FROM photos
       WHERE id = ? AND user_id = ? AND deleted_at IS NULL AND object_key != ''`,
    )
    .bind(photoId, userId)
    .first<{ id: string; object_key: string; content_type: string }>();
  if (!row) throw new ApiError(404, "not_found", "Photo not found.");
  return row;
}
