/** Shared document shapes and constants. Mirrors the Dart models in lib/. */

export const SCHEMA_VERSION = 1;

/** Keep every function in one region so Firestore triggers stay co-located. */
export const DEFAULT_REGION = "us-central1";

export type CareEventType =
  | "watered"
  | "fertilized"
  | "pruned"
  | "repotted"
  | "transplanted"
  | "harvested"
  | "deadheaded"
  | "mulched"
  | "pest_inspection"
  | "pest_treatment"
  | "disease_observation"
  | "weather_damage"
  | "photo_added"
  | "health_check"
  | "planted"
  | "acquired"
  | "archived";

export type ReminderTaskType =
  | "water_check"
  | "fertilize"
  | "prune"
  | "repot"
  | "pest_check"
  | "harvest"
  | "seasonal_task"
  | "custom";

export type ReminderStatus =
  | "open"
  | "completed"
  | "skipped"
  | "snoozed"
  | "expired"
  | "cancelled";

export type ReminderPriority = "low" | "normal" | "high";

/** One schedulable task on a species care profile. */
export interface CareProfileTask {
  taskType: ReminderTaskType;
  title: string;
  instructions: string | null;
  intervalDays: number;
  priority: ReminderPriority;
  /** Source fields the interval was derived from, for re-derivation later. */
  basis: string[];
}

export interface CareProfileDoc {
  label: string;
  isDerived: boolean;
  derivedFrom: {
    provider: string;
    sourceId: string;
    fields: string[];
  } | null;
  tasks: CareProfileTask[];
  schemaVersion: number;
}

/** Document id of the care profile derived from catalog data. */
export const DERIVED_CARE_PROFILE_ID = "derived-v1";

export function daysFromNow(days: number): Date {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
}
