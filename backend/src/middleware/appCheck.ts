import type { MiddlewareHandler } from "hono";
import type { AppEnv } from "../env";
import { ApiError } from "../http/errors";

/**
 * Report-only until APP_CHECK_ENFORCE is "true". Enforcement checks that the
 * header is a JWT-shaped token. Signature checks against the App Check JWKS
 * belong with that switch, once the app sends the header.
 */
export function appCheckMiddleware(): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    if (c.req.method === "OPTIONS") return next();
    const path = new URL(c.req.url).pathname;
    if (path === "/health") return next();

    const header = c.req.header("X-Firebase-AppCheck");
    const enforce = c.env.APP_CHECK_ENFORCE === "true";
    const shaped = !!header && header.split(".").length === 3;
    if (!shaped) {
      if (enforce) {
        throw new ApiError(401, "unauthenticated", "App Check is required.");
      }
      if (!header) {
        console.log(
          JSON.stringify({
            message: "app_check_missing",
            path,
            userId: c.get("userId"),
          }),
        );
      }
    }
    await next();
  };
}
