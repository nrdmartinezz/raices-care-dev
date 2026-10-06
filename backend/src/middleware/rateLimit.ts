import type { MiddlewareHandler } from "hono";
import { WRITE_LIMIT_PER_MINUTE, type AppEnv } from "../env";
import { ApiError } from "../http/errors";

const WRITES = new Set(["POST", "PATCH", "PUT", "DELETE"]);

/**
 * Per-user write window stored in D1. A Workers Rate Limiting binding can
 * replace this without changing the routes.
 */
export function rateLimitMiddleware(): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    if (!WRITES.has(c.req.method)) return next();
    const userId = c.get("userId");
    if (!userId) return next();
    const windowStart = Math.floor(Date.now() / 60_000) * 60_000;
    const existing = await c.env.DB.prepare(
      "SELECT hits FROM write_rates WHERE user_id = ? AND window_start = ?",
    )
      .bind(userId, windowStart)
      .first<{ hits: number }>();
    if ((existing?.hits ?? 0) >= WRITE_LIMIT_PER_MINUTE) {
      throw new ApiError(429, "rate_limited", "Too many writes. Try again shortly.");
    }
    await c.env.DB.prepare(
      `INSERT INTO write_rates (user_id, window_start, hits)
       VALUES (?, ?, 1)
       ON CONFLICT(user_id, window_start) DO UPDATE SET hits = hits + 1`,
    )
      .bind(userId, windowStart)
      .run();
    await next();
  };
}
