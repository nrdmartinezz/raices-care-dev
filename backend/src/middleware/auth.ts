import type { MiddlewareHandler } from "hono";
import type { JWTVerifyGetKey } from "jose";
import { developmentUser, verifyFirebaseToken } from "../auth/firebase";
import type { AppEnv } from "../env";
import { ApiError } from "../http/errors";

const PUBLIC_ROUTES = new Set(["GET /health"]);

export function authMiddleware(keys?: JWTVerifyGetKey): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    if (c.req.method === "OPTIONS") return next();
    const path = new URL(c.req.url).pathname;
    if (PUBLIC_ROUTES.has(`${c.req.method} ${path}`)) return next();

    const header = c.req.header("Authorization") ?? "";
    const match = /^Bearer\s+(\S+)$/i.exec(header);
    if (!match) {
      throw new ApiError(401, "unauthenticated", "Sign in is required.");
    }
    const token = match[1];
    const dev = developmentUser(token, c.env);
    const user = dev ?? (await verifyFirebaseToken(token, c.env, keys));
    c.set("userId", user.userId);
    c.set("authSubject", user.subject);
    await next();
  };
}
