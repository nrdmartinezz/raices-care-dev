import type { MiddlewareHandler } from "hono";
import type { AppEnv } from "../env";

function allowed(origin: string, env: AppEnv["Bindings"]): boolean {
  const configured = (env.ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  if (configured.includes(origin)) return true;
  if (env.ENVIRONMENT !== "development") return false;
  try {
    const url = new URL(origin);
    return url.hostname === "localhost" || url.hostname === "127.0.0.1";
  } catch {
    return false;
  }
}

export function corsMiddleware(): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    const origin = c.req.header("Origin");
    const ok = !!origin && allowed(origin, c.env);
    if (c.req.method === "OPTIONS") {
      const headers = new Headers();
      if (ok && origin) {
        headers.set("Access-Control-Allow-Origin", origin);
        headers.set("Vary", "Origin");
        headers.set(
          "Access-Control-Allow-Headers",
          "Authorization, Content-Type, If-Match, Idempotency-Key, X-Firebase-AppCheck",
        );
        headers.set("Access-Control-Allow-Methods", "GET, POST, PATCH, PUT, DELETE, OPTIONS");
        headers.set("Access-Control-Max-Age", "600");
      }
      return new Response(null, { status: 204, headers });
    }
    await next();
    if (ok && origin) {
      c.res.headers.set("Access-Control-Allow-Origin", origin);
      c.res.headers.set("Vary", "Origin");
    }
  };
}
