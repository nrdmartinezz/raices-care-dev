import {
  parseAppliesTo,
  parseRuleJson,
  renderCarePlan,
  selectCareProfile,
  isNewlyPlanted,
  normalizeZone,
  type CarePlan,
  type CareProfileRecord,
  type CareRuleRecord,
  type PlantCareContext,
} from "./care_rules";
import type { CareTask } from "../services/reminders";

export type AssignInput = {
  userId: string;
  plantId: string;
  speciesId: string | null;
  locationType: string | null;
  growingMethod: string | null;
  sunlight: string | null;
  hardinessZone: string | null;
  plantedAt: number | null;
  plantAgeStage: string | null;
  at: number;
};

export function planTasks(plan: CarePlan): CareTask[] {
  return plan.items
    .filter((item) => item.checkEveryDays && item.checkEveryDays > 0)
    .map((item) => ({
      taskType: item.taskType,
      title: item.title,
      intervalDays: item.checkEveryDays ?? undefined,
      instructions: item.instruction,
      priority: "normal",
    }));
}

export async function assignCarePlan(
  db: D1Database,
  input: AssignInput,
): Promise<{ profileId: string | null; tasks: CareTask[] }> {
  const zone =
    normalizeZone(input.hardinessZone) ??
    (await savedZone(db, input.userId));
  const context: PlantCareContext = {
    locationType: input.locationType,
    growingMethod: input.growingMethod,
    sunlight: input.sunlight,
    hardinessZone: zone,
    newlyPlanted: isNewlyPlanted({
      plantedAt: input.plantedAt,
      plantAgeStage: input.plantAgeStage,
      at: input.at,
    }),
  };
  await db
    .prepare("UPDATE plants SET context_json = ? WHERE id = ? AND user_id = ?")
    .bind(JSON.stringify(context), input.plantId, input.userId)
    .run();
  if (zone) {
    await db
      .prepare(
        "UPDATE users SET hardiness_zone = ? WHERE id = ? AND deleted_at IS NULL",
      )
      .bind(zone, input.userId)
      .run();
  }
  if (!input.speciesId) return { profileId: null, tasks: [] };

  const profileRows = await db
    .prepare(
      `SELECT id, name, applies_to_json, status, version, tasks_json
       FROM care_profiles WHERE species_id = ? AND status = 'published'`,
    )
    .bind(input.speciesId)
    .all<{
      id: string;
      name: string;
      applies_to_json: string;
      status: string;
      version: number;
      tasks_json: string;
    }>();
  const profiles: CareProfileRecord[] = (profileRows.results ?? []).map((row) => ({
    id: row.id,
    name: row.name,
    appliesTo: parseAppliesTo(row.applies_to_json),
    status: row.status,
    version: row.version,
    tasksJson: row.tasks_json,
  }));
  const species = await db
    .prepare("SELECT default_care_profile_id FROM species WHERE id = ?")
    .bind(input.speciesId)
    .first<{ default_care_profile_id: string | null }>();
  const selected = selectCareProfile(
    profiles,
    context,
    species?.default_care_profile_id ?? null,
  );
  if (!selected) return { profileId: null, tasks: [] };

  const ruleRows = await db
    .prepare(
      `SELECT id, care_profile_id, task_type, rule_json, display_order, status
       FROM care_rules WHERE care_profile_id = ?`,
    )
    .bind(selected.id)
    .all<{
      id: string;
      care_profile_id: string;
      task_type: string;
      rule_json: string;
      display_order: number;
      status: string;
    }>();
  const rules: CareRuleRecord[] = (ruleRows.results ?? []).map((row) => ({
    id: row.id,
    careProfileId: row.care_profile_id,
    taskType: row.task_type,
    rule: parseRuleJson(row.rule_json),
    displayOrder: row.display_order,
    status: row.status,
  }));
  const plan = renderCarePlan({
    profile: selected,
    rules,
    context,
    at: new Date(input.at),
  });
  await db.batch([
    db
      .prepare(
        "UPDATE plants SET care_profile_id = ? WHERE id = ? AND user_id = ?",
      )
      .bind(selected.id, input.plantId, input.userId),
    db
      .prepare(
        `INSERT INTO plant_care_plans (
          id, plant_id, care_profile_id, profile_version, plan_json, generated_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO NOTHING`,
      )
      .bind(
        `${input.plantId}__plan`,
        input.plantId,
        selected.id,
        plan.careProfileVersion,
        JSON.stringify(plan),
        input.at,
      ),
  ]);
  return { profileId: selected.id, tasks: planTasks(plan) };
}

async function savedZone(db: D1Database, userId: string): Promise<string | null> {
  const row = await db
    .prepare("SELECT hardiness_zone FROM users WHERE id = ? AND deleted_at IS NULL")
    .bind(userId)
    .first<{ hardiness_zone: string | null }>();
  return normalizeZone(row?.hardiness_zone);
}
