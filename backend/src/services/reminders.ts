import type { Env } from "../env";
import { now, readJson } from "../http/ids";

export type CareTask = {
  taskType?: string;
  title?: string;
  intervalDays?: number;
  instructions?: string;
  priority?: string;
};

const DAY = 24 * 60 * 60 * 1000;

type Effect = {
  taskType: string;
  lastColumn: string;
  nextColumn: string;
  fallbackDays: number;
};

const CARE_EFFECTS: Record<string, Effect> = {
  watered: {
    taskType: "water_check",
    lastColumn: "last_watered_at",
    nextColumn: "next_water_check_at",
    fallbackDays: 7,
  },
  fertilized: {
    taskType: "fertilize",
    lastColumn: "last_fertilized_at",
    nextColumn: "next_fertilize_at",
    fallbackDays: 30,
  },
  pest_inspection: {
    taskType: "pest_check",
    lastColumn: "last_pest_check_at",
    nextColumn: "next_pest_check_at",
    fallbackDays: 14,
  },
  pest_treatment: {
    taskType: "pest_check",
    lastColumn: "last_pest_check_at",
    nextColumn: "next_pest_check_at",
    fallbackDays: 14,
  },
};

export async function seedPlantReminders(
  db: D1Database,
  input: {
    userId: string;
    plantId: string;
    speciesId: string | null;
    careProfileId?: string | null;
  },
): Promise<void> {
  if (!input.speciesId) return;
  const profile = input.careProfileId
    ? await db
        .prepare("SELECT tasks_json FROM care_profiles WHERE id = ? AND species_id = ?")
        .bind(input.careProfileId, input.speciesId)
        .first<{ tasks_json: string }>()
    : await db
        .prepare(
          "SELECT tasks_json FROM care_profiles WHERE species_id = ? ORDER BY id LIMIT 1",
        )
        .bind(input.speciesId)
        .first<{ tasks_json: string }>();
  if (!profile) return;

  const tasks = readJson<CareTask[]>(profile.tasks_json, []);
  const created = now();
  const statements: D1PreparedStatement[] = [];
  for (const task of tasks) {
    if (!task.taskType || !task.intervalDays) continue;
    const id = `${input.plantId}__${task.taskType}`;
    statements.push(
      db
        .prepare(
          `INSERT INTO reminders (
            id, user_id, plant_id, species_id, task_type, title, instructions,
            due_at, status, priority, interval_days, schedule_source,
            created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'open', ?, ?, 'care_profile', ?, ?)
          ON CONFLICT(id) DO NOTHING`,
        )
        .bind(
          id,
          input.userId,
          input.plantId,
          input.speciesId,
          task.taskType,
          task.title || task.taskType,
          task.instructions ?? null,
          created + task.intervalDays * DAY,
          task.priority ?? "normal",
          task.intervalDays,
          created,
          created,
        ),
    );
  }
  if (statements.length > 0) await db.batch(statements);
}

export async function applyCareEvent(
  db: D1Database,
  input: {
    userId: string;
    plantId: string;
    eventType: string;
    occurredAt: number;
  },
): Promise<void> {
  const effect = CARE_EFFECTS[input.eventType];
  if (!effect) return;

  const plant = await db
    .prepare(
      `SELECT ${effect.lastColumn} AS last_done FROM plants
       WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
    )
    .bind(input.plantId, input.userId)
    .first<{ last_done: number | null }>();
  if (!plant) return;
  if (plant.last_done !== null && plant.last_done >= input.occurredAt) return;

  const canonicalId = `${input.plantId}__${effect.taskType}`;
  const canonical = await db
    .prepare(
      "SELECT interval_days FROM reminders WHERE id = ? AND user_id = ? AND deleted_at IS NULL",
    )
    .bind(canonicalId, input.userId)
    .first<{ interval_days: number | null }>();
  const intervalDays = canonical?.interval_days ?? effect.fallbackDays;
  const nextDue = input.occurredAt + intervalDays * DAY;
  const updated = now();

  await db.batch([
    db
      .prepare(
        `UPDATE plants SET ${effect.lastColumn} = ?, ${effect.nextColumn} = ?, updated_at = ?,
         revision = revision + 1
         WHERE id = ? AND user_id = ? AND deleted_at IS NULL
           AND (${effect.lastColumn} IS NULL OR ${effect.lastColumn} < ?)`,
      )
      .bind(input.occurredAt, nextDue, updated, input.plantId, input.userId, input.occurredAt),
    db
      .prepare(
        `UPDATE reminders SET due_at = ?, status = 'open', completed_at = ?, snoozed_until = NULL,
         updated_at = ?
         WHERE id = ? AND user_id = ? AND deleted_at IS NULL`,
      )
      .bind(nextDue, input.occurredAt, updated, canonicalId, input.userId),
    db
      .prepare(
        `UPDATE reminders SET status = 'completed', completed_at = ?, updated_at = ?
         WHERE user_id = ? AND plant_id = ? AND task_type = ? AND status = 'open'
           AND id != ? AND deleted_at IS NULL`,
      )
      .bind(
        input.occurredAt,
        updated,
        input.userId,
        input.plantId,
        effect.taskType,
        canonicalId,
      ),
  ]);
}

export type DueReminder = {
  id: string;
  user_id: string;
  plant_id: string;
  title: string;
  due_at: number;
  task_type: string;
};

export async function listDueReminders(env: Env, asOf = now()): Promise<DueReminder[]> {
  const result = await env.DB.prepare(
    `SELECT r.id, r.user_id, r.plant_id, r.title, r.due_at, r.task_type
     FROM reminders r
     JOIN users u ON u.id = r.user_id
     WHERE r.status = 'open'
       AND r.deleted_at IS NULL
       AND u.deleted_at IS NULL
       AND r.due_at <= ?
       AND (r.snoozed_until IS NULL OR r.snoozed_until <= ?)
     ORDER BY r.due_at
     LIMIT 100`,
  )
    .bind(asOf, asOf)
    .all<DueReminder>();
  return result.results ?? [];
}
