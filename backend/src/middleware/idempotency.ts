import type { MiddlewareHandler } from "hono";
import type { AppEnv } from "../env";
import { ApiError } from "../http/errors";
import { now, sha256 } from "../http/ids";

export function idempotencyMiddleware(): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    if (c.req.method !== "POST") return next();
    const key = c.req.header("Idempotency-Key");
    if (!key || key.length > 128) return next();
    const contentType = c.req.header("content-type") ?? "";
    if (contentType.startsWith("image/")) return next();

    const userId = c.get("userId");
    const body = await c.req.raw.clone().text();
    const requestHash = await sha256(`${c.req.method} ${new URL(c.req.url).pathname} ${body}`);
    const existing = await c.env.DB.prepare(
      "SELECT request_hash, status, response_json FROM idempotency_keys WHERE user_id = ? AND key = ?",
    )
      .bind(userId, key)
      .first<{ request_hash: string; status: number; response_json: string }>();

    if (existing) {
      if (existing.request_hash !== requestHash) {
        throw new ApiError(
          409,
          "conflict",
          "This idempotency key was already used for a different request.",
        );
      }
      return c.body(existing.response_json, existing.status as 200, {
        "content-type": "application/json",
      });
    }

    await next();
    const responseText = await c.res.clone().text();
    await c.env.DB.prepare(
      `INSERT INTO idempotency_keys
        (user_id, key, request_hash, status, response_json, created_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id, key) DO NOTHING`,
    )
      .bind(userId, key, requestHash, c.res.status, responseText, now())
      .run();
  };
}
