-- Structured care profiles. Existing species, plants, and reminders stay.
-- Timestamps are epoch milliseconds. Existing rows stay published so the
-- current catalog keeps seeding reminders.

ALTER TABLE species ADD COLUMN primary_common_name TEXT;
ALTER TABLE species ADD COLUMN default_care_profile_id TEXT;
ALTER TABLE species ADD COLUMN status TEXT NOT NULL DEFAULT 'published';

ALTER TABLE care_profiles ADD COLUMN applies_to_json TEXT NOT NULL DEFAULT '{}';
ALTER TABLE care_profiles ADD COLUMN status TEXT NOT NULL DEFAULT 'published';
ALTER TABLE care_profiles ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE care_profiles ADD COLUMN reviewed_at INTEGER;
ALTER TABLE care_profiles ADD COLUMN source_refs_json TEXT NOT NULL DEFAULT '[]';

ALTER TABLE plants ADD COLUMN care_profile_id TEXT;
ALTER TABLE plants ADD COLUMN context_json TEXT NOT NULL DEFAULT '{}';

ALTER TABLE users ADD COLUMN hardiness_zone TEXT;

CREATE TABLE care_rules (
  id TEXT PRIMARY KEY,
  care_profile_id TEXT NOT NULL,
  task_type TEXT NOT NULL,
  rule_json TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft'
);

CREATE INDEX care_rules_profile ON care_rules (care_profile_id, display_order);

CREATE TABLE data_sources (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  license TEXT NOT NULL,
  retrieved_at INTEGER NOT NULL
);

CREATE TABLE plant_care_plans (
  id TEXT PRIMARY KEY,
  plant_id TEXT NOT NULL,
  care_profile_id TEXT NOT NULL,
  profile_version INTEGER NOT NULL,
  plan_json TEXT NOT NULL,
  generated_at INTEGER NOT NULL
);

CREATE INDEX plant_care_plans_plant ON plant_care_plans (plant_id, generated_at);
