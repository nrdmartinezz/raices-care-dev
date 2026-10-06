import { createApp } from "./app";
import type { Env } from "./env";
import { cleanupDeletedPhotos } from "./services/photos";
import { runReminderCron } from "./services/push";

const app = createApp();

export default {
  fetch: app.fetch,
  async scheduled(_event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(
      (async () => {
        await runReminderCron(env);
        await cleanupDeletedPhotos(env);
      })(),
    );
  },
};
