import { Hono } from "hono";
import type { JWTVerifyGetKey } from "jose";
import type { AppEnv } from "./env";
import { onError } from "./http/errors";
import { appCheckMiddleware } from "./middleware/appCheck";
import { authMiddleware } from "./middleware/auth";
import { corsMiddleware } from "./middleware/cors";
import { idempotencyMiddleware } from "./middleware/idempotency";
import { logMiddleware } from "./middleware/log";
import { rateLimitMiddleware } from "./middleware/rateLimit";
import { careRoutes } from "./routes/care";
import { gardenRoutes } from "./routes/gardens";
import { healthRoutes } from "./routes/health";
import { meRoutes } from "./routes/me";
import { photoRoutes } from "./routes/photos";
import { plantRoutes } from "./routes/plants";
import { plantingRoutes } from "./routes/planting";
import { reminderRoutes } from "./routes/reminders";
import { speciesRoutes } from "./routes/species";

export function createApp(options?: { jwks?: JWTVerifyGetKey }) {
  const app = new Hono<AppEnv>();
  app.onError(onError);
  app.use("*", logMiddleware());
  app.use("*", corsMiddleware());
  app.use("*", authMiddleware(options?.jwks));
  app.use("*", appCheckMiddleware());
  app.use("*", rateLimitMiddleware());
  app.use("*", idempotencyMiddleware());
  app.route("/", healthRoutes);
  app.route("/", meRoutes);
  app.route("/", speciesRoutes);
  app.route("/", plantingRoutes);
  app.route("/", gardenRoutes);
  app.route("/", plantRoutes);
  app.route("/", careRoutes);
  app.route("/", reminderRoutes);
  app.route("/", photoRoutes);
  app.notFound((c) =>
    c.json({ error: { code: "not_found", message: "Not found.", details: {} } }, 404),
  );
  return app;
}
