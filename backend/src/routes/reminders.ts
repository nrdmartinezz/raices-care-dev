import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { parseBody, readObject } from "../http/body";
import { pageLimit } from "../http/cursor";
import { ApiError } from "../http/errors";
import { clientId, iso, now, optionalClientId, parseTime } from "../http/ids";
import { loadPlant } from "./plants";

export const reminderRoutes = new Hono<AppEnv>();

const taskTypes = [
  "water_check",
  "fertilize",
  "prune",
  "repot",
  "pest_check",
  "harvest",
  "seasonal_task",
  "custom",
] as const;

const createSchema = z
  .object({
    id: z.string().optional(),
    plantId: z.string().min(1),
    taskType: z.enum(taskTypes),
    title: z.string().min(1).max(160),
    instructions: z.string().max(2000).nullable().optional(),
    dueAt: z.union([z.string(), z.number()]),
    priority: z.enum(["low", "normal", "high"]).optional(),
    intervalDays: z.number().int().positive().max(3650).nullable().optional(),
  })
  .strict();

type ReminderRow = {
  id: string;
  plant_id: string;
  species_id: string | null;
  task_type: string;
  title: string;
  instructions: string | null;
  due_at: number;
  status: string;
  priority: string;
  interval_days: number | null;
  schedule_source: string;
  completed_at: number | null;
  snoozed_until: number | null;
  created_at: number;
  updated_at: number;
};

function reminderJson(row: ReminderRow) {
  return {
    id: row.id,
    plantId: row.plant_id,
    speciesId: row.species_id,
    taskType: row.task_type,
    title: row.title,
    instructions: row.instructions,
    dueAt: iso(row.due_at),
    status: row.status,
    priority: row.priority,
    intervalDays: row.interval_days,
    scheduleSource: row.schedule_source,
    completedAt: iso(row.completed_at),
    snoozedUntil: iso(row.snoozed_until),
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
  };
}

reminderRoutes.get("/v1/reminders", async (c) => {
  const userId = c.get("userId");
  const limit = pageLimit(c.req.query("limit"));
  const status = c.req.query("status") ?? "open";
  const dueBefore = c.req.query("dueBefore");
  const plantId = c.req.query("plantId");
  const due = dueBefore ? parseTime(dueBefore, "dueBefore") : null;
  const rows = await c.env.DB.prepare(
    `SELECT id, plant_id, species_id, task_type, title, instructions, due_at, status,
            priority, interval_days, schedule_source, completed_at, snoozed_until,
            created_at, updated_at
     FROM reminders
     WHERE user_id = ? AND deleted_at IS NULL
       AND (? = 'any' OR status = ?)
       AND (? IS NULL OR plant_id = ?)
       AND (? IS NULL OR due_at <= ?)
     ORDER BY due_at ASC, id ASC
     LIMIT ?`,
  )
    .bind(userId, status, status, plantId ?? null, plantId ?? null, due, due, limit)
    .all<ReminderRow>();
  return c.json({ results: (rows.results ?? []).map(reminderJson) });
});

reminderRoutes.post("/v1/reminders", async (c) => {
  const userId = c.get("userId");
  const body = parseBody(createSchema, await readObject(c));
  const plantId = clientId(body.plantId, "plantId");
  const plant = await loadPlant(c.env.DB, userId, plantId);
  const id = optionalClientId(body.id, "id");
  const ts = now();
  const dueAt = parseTime(body.dueAt, "dueAt");
  await c.env.DB.prepare(
    `INSERT INTO reminders (
      id, user_id, plant_id, species_id, task_type, title, instructions, due_at,
      status, priority, interval_days, schedule_source, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'open', ?, ?, 'user', ?, ?)
    ON CONFLICT(id) DO NOTHING`,
  )
    .bind(
      id,
      userId,
      plantId,
      plant.species_id,
      body.taskType,
      body.title,
      body.instructions ?? null,
      dueAt,
      body.priority ?? "normal",
      body.intervalDays ?? null,
      ts,
      ts,
    )
    .run();
  const row = await loadReminder(c.env.DB, userId, id);
  return c.json(reminderJson(row), 201);
});

reminderRoutes.post("/v1/reminders/:reminderId/complete", async (c) => {
  const row = await setStatus(c, "completed");
  return c.json(reminderJson(row));
});

reminderRoutes.post("/v1/reminders/:reminderId/snooze", async (c) => {
  const userId = c.get("userId");
  const reminderId = clientId(c.req.param("reminderId"), "reminderId");
  await loadReminder(c.env.DB, userId, reminderId);
  const body = parseBody(
    z.object({ until: z.union([z.string(), z.number()]) }).strict(),
    await readObject(c),
  );
  const until = parseTime(body.until, "until");
  const ts = now();
  await c.env.DB.prepare(
    `UPDATE reminders SET status = 'snoozed', snoozed_until = ?, due_at = ?, updated_at = ?
     WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
  )
    .bind(until, until, ts, reminderId, userId)
    .run();
  return c.json(reminderJson(await loadReminder(c.env.DB, userId, reminderId)));
});

reminderRoutes.post("/v1/reminders/:reminderId/skip", async (c) => {
  return c.json(reminderJson(await setStatus(c, "skipped")));
});

reminderRoutes.post("/v1/reminders/:reminderId/cancel", async (c) => {
  return c.json(reminderJson(await setStatus(c, "cancelled")));
});

reminderRoutes.post("/v1/reminders/:reminderId/reopen", async (c) => {
  const userId = c.get("userId");
  const reminderId = clientId(c.req.param("reminderId"), "reminderId");
  await loadReminder(c.env.DB, userId, reminderId);
  const body = parseBody(
    z.object({ dueAt: z.union([z.string(), z.number()]) }).strict(),
    await readObject(c),
  );
  const dueAt = parseTime(body.dueAt, "dueAt");
  const ts = now();
  await c.env.DB.prepare(
    `UPDATE reminders SET status = 'open', due_at = ?, snoozed_until = NULL,
      completed_at = NULL, updated_at = ?
     WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
  )
    .bind(dueAt, ts, reminderId, userId)
    .run();
  return c.json(reminderJson(await loadReminder(c.env.DB, userId, reminderId)));
});

reminderRoutes.delete("/v1/reminders/:reminderId", async (c) => {
  const userId = c.get("userId");
  const reminderId = clientId(c.req.param("reminderId"), "reminderId");
  const result = await c.env.DB.prepare(
    "UPDATE reminders SET deleted_at = ?, updated_at = ? WHERE id = ? AND user_id = ? AND deleted_at IS NULL",
  )
    .bind(now(), now(), reminderId, userId)
    .run();
  if ((result.meta.changes ?? 0) === 0) {
    throw new ApiError(404, "not_found", "Reminder not found.");
  }
  return c.body(null, 204);
});

async function setStatus(
  c: { env: AppEnv["Bindings"]; get: (key: "userId") => string; req: { param: (name: string) => string } },
  status: "completed" | "skipped" | "cancelled",
) {
  const userId = c.get("userId");
  const reminderId = clientId(c.req.param("reminderId"), "reminderId");
  await loadReminder(c.env.DB, userId, reminderId);
  const ts = now();
  await c.env.DB.prepare(
    `UPDATE reminders SET status = ?, completed_at = ?, updated_at = ?
     WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
  )
    .bind(status, ts, ts, reminderId, userId)
    .run();
  return loadReminder(c.env.DB, userId, reminderId);
}

async function loadReminder(db: D1Database, userId: string, reminderId: string): Promise<ReminderRow> {
  const row = await db
    .prepare(
      `SELECT id, plant_id, species_id, task_type, title, instructions, due_at, status,
              priority, interval_days, schedule_source, completed_at, snoozed_until,
              created_at, updated_at
       FROM reminders WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
    )
    .bind(reminderId, userId)
    .first<ReminderRow>();
  if (!row) throw new ApiError(404, "not_found", "Reminder not found.");
  return row;
}
