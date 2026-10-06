import { Hono } from "hono";
import type { AppEnv } from "../env";

export const healthRoutes = new Hono<AppEnv>();

healthRoutes.get("/health", (c) => {
  return c.json({ ok: true, service: "raices-api" });
});
