import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { parseBody, readObject } from "../http/body";
import { ApiError } from "../http/errors";
import { iso, now } from "../http/ids";
import { avatarKey, readImageBody, sniffImage } from "../services/photos";

export const meRoutes = new Hono<AppEnv>();

const profileSchema = z
  .object({
    email: z.string().email().max(320).nullable().optional(),
    displayName: z.string().max(120).nullable().optional(),
    locale: z.string().max(35).nullable().optional(),
    timezone: z.string().max(80).nullable().optional(),
  })
  .strict();

const deviceSchema = z
  .object({
    token: z.string().min(1).max(4096),
    platform: z.enum(["ios", "android", "web"]).optional(),
  })
  .strict();

async function ensureUser(db: D1Database, userId: string): Promise<void> {
  const ts = now();
  await db
    .prepare("INSERT INTO users (id, created_at, updated_at) VALUES (?, ?, ?) ON CONFLICT(id) DO NOTHING")
    .bind(userId, ts, ts)
    .run();
}

function userJson(row: {
  id: string;
  email: string | null;
  display_name: string | null;
  locale: string | null;
  timezone: string | null;
  avatar_object_key: string | null;
  created_at: number;
  updated_at: number;
}) {
  return {
    id: row.id,
    email: row.email,
    displayName: row.display_name,
    locale: row.locale,
    timezone: row.timezone,
    hasAvatar: !!row.avatar_object_key,
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
  };
}

meRoutes.get("/v1/me", async (c) => {
  const userId = c.get("userId");
  await ensureUser(c.env.DB, userId);
  const row = await c.env.DB.prepare(
    `SELECT id, email, display_name, locale, timezone, avatar_object_key, created_at, updated_at
     FROM users WHERE id = ? AND deleted_at IS NULL`,
  )
    .bind(userId)
    .first<Parameters<typeof userJson>[0]>();
  if (!row) throw new ApiError(404, "not_found", "Account not found.");
  return c.json(userJson(row));
});

meRoutes.put("/v1/me", async (c) => {
  const userId = c.get("userId");
  const body = parseBody(profileSchema, await readObject(c));
  const ts = now();
  await ensureUser(c.env.DB, userId);
  await c.env.DB.prepare(
    `UPDATE users SET
      email = COALESCE(?, email),
      display_name = COALESCE(?, display_name),
      locale = COALESCE(?, locale),
      timezone = COALESCE(?, timezone),
      updated_at = ?
     WHERE id = ? AND deleted_at IS NULL`,
  )
    .bind(
      body.email === undefined ? null : body.email,
      body.displayName === undefined ? null : body.displayName,
      body.locale === undefined ? null : body.locale,
      body.timezone === undefined ? null : body.timezone,
      ts,
      userId,
    )
    .run();
  const row = await c.env.DB.prepare(
    `SELECT id, email, display_name, locale, timezone, avatar_object_key, created_at, updated_at
     FROM users WHERE id = ? AND deleted_at IS NULL`,
  )
    .bind(userId)
    .first<Parameters<typeof userJson>[0]>();
  if (!row) throw new ApiError(404, "not_found", "Account not found.");
  return c.json(userJson(row));
});

meRoutes.delete("/v1/me", async (c) => {
  const userId = c.get("userId");
  const ts = now();
  const photos = await c.env.DB.prepare(
    "SELECT object_key FROM photos WHERE user_id = ? AND object_key != ''",
  )
    .bind(userId)
    .all<{ object_key: string }>();
  const user = await c.env.DB.prepare("SELECT avatar_object_key FROM users WHERE id = ?")
    .bind(userId)
    .first<{ avatar_object_key: string | null }>();
  await c.env.DB.batch([
    c.env.DB.prepare("UPDATE users SET deleted_at = ?, updated_at = ? WHERE id = ?").bind(ts, ts, userId),
    c.env.DB.prepare("UPDATE gardens SET deleted_at = ?, updated_at = ? WHERE user_id = ? AND deleted_at IS NULL").bind(ts, ts, userId),
    c.env.DB.prepare("UPDATE plants SET deleted_at = ?, updated_at = ? WHERE user_id = ? AND deleted_at IS NULL").bind(ts, ts, userId),
    c.env.DB.prepare("UPDATE reminders SET deleted_at = ?, updated_at = ? WHERE user_id = ? AND deleted_at IS NULL").bind(ts, ts, userId),
    c.env.DB.prepare("UPDATE care_events SET deleted_at = ? WHERE user_id = ? AND deleted_at IS NULL").bind(ts, userId),
    c.env.DB.prepare("UPDATE photos SET deleted_at = ? WHERE user_id = ? AND deleted_at IS NULL").bind(ts, userId),
    c.env.DB.prepare("DELETE FROM device_tokens WHERE user_id = ?").bind(userId),
    c.env.DB.prepare("DELETE FROM notification_deliveries WHERE user_id = ?").bind(userId),
    c.env.DB.prepare("DELETE FROM idempotency_keys WHERE user_id = ?").bind(userId),
    c.env.DB.prepare("DELETE FROM write_rates WHERE user_id = ?").bind(userId),
  ]);
  for (const photo of photos.results ?? []) {
    await c.env.IMAGES.delete(photo.object_key);
  }
  if (user?.avatar_object_key) await c.env.IMAGES.delete(user.avatar_object_key);
  return c.body(null, 204);
});

meRoutes.post("/v1/me/devices", async (c) => {
  const userId = c.get("userId");
  const body = parseBody(deviceSchema, await readObject(c));
  const ts = now();
  await ensureUser(c.env.DB, userId);
  await c.env.DB.prepare(
    `INSERT INTO device_tokens (token, user_id, platform, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(user_id, token) DO UPDATE SET platform = excluded.platform, updated_at = excluded.updated_at`,
  )
    .bind(body.token, userId, body.platform ?? null, ts, ts)
    .run();
  return c.json({ token: body.token, platform: body.platform ?? null }, 201);
});

meRoutes.delete("/v1/me/devices", async (c) => {
  const userId = c.get("userId");
  const body = parseBody(z.object({ token: z.string().min(1) }).strict(), await readObject(c));
  await c.env.DB.prepare("DELETE FROM device_tokens WHERE user_id = ? AND token = ?")
    .bind(userId, body.token)
    .run();
  return c.body(null, 204);
});

meRoutes.put("/v1/me/avatar", async (c) => {
  const userId = c.get("userId");
  await ensureUser(c.env.DB, userId);
  const bytes = await readImageBody(c.req.raw);
  const sniffed = sniffImage(bytes);
  if (sniffed.contentType !== "image/jpeg") {
    throw new ApiError(415, "unsupported_media_type", "Profile photos must be JPEG.");
  }
  const key = avatarKey(userId);
  await c.env.IMAGES.put(key, bytes, {
    httpMetadata: { contentType: "image/jpeg" },
  });
  await c.env.DB.prepare("UPDATE users SET avatar_object_key = ?, updated_at = ? WHERE id = ?")
    .bind(key, now(), userId)
    .run();
  return c.json({ hasAvatar: true, byteSize: bytes.byteLength, contentType: "image/jpeg" });
});

meRoutes.get("/v1/me/avatar", async (c) => {
  const userId = c.get("userId");
  const row = await c.env.DB.prepare(
    "SELECT avatar_object_key FROM users WHERE id = ? AND deleted_at IS NULL",
  )
    .bind(userId)
    .first<{ avatar_object_key: string | null }>();
  if (!row?.avatar_object_key) throw new ApiError(404, "not_found", "Profile photo not found.");
  const object = await c.env.IMAGES.get(row.avatar_object_key);
  if (!object) throw new ApiError(404, "not_found", "Profile photo not found.");
  return new Response(object.body, {
    headers: {
      "content-type": "image/jpeg",
      "cache-control": "private, max-age=300",
    },
  });
});

meRoutes.delete("/v1/me/avatar", async (c) => {
  const userId = c.get("userId");
  const key = avatarKey(userId);
  await c.env.IMAGES.delete(key);
  await c.env.DB.prepare(
    "UPDATE users SET avatar_object_key = NULL, updated_at = ? WHERE id = ?",
  )
    .bind(now(), userId)
    .run();
  return c.body(null, 204);
});
