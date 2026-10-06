import type { MiddlewareHandler } from "hono";
import type { AppEnv } from "../env";

export function logMiddleware(): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    const started = Date.now();
    await next();
    console.log(
      JSON.stringify({
        method: c.req.method,
        path: new URL(c.req.url).pathname,
        status: c.res.status,
        ms: Date.now() - started,
        userId: c.get("userId") ?? null,
      }),
    );
  };
}
