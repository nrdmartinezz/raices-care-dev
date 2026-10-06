-- Raíces local schema. Timestamps are epoch milliseconds.
-- Profile photos are not a table: they live at users/{userId}/profile/avatar.jpg.

CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT,
  display_name TEXT,
  locale TEXT,
  timezone TEXT,
  avatar_object_key TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE gardens (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  timezone TEXT,
  latitude REAL,
  longitude REAL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE species (
  id TEXT PRIMARY KEY,
  scientific_name TEXT NOT NULL,
  common_names_json TEXT NOT NULL DEFAULT '[]',
  plant_groups_json TEXT NOT NULL DEFAULT '[]',
  toxicity_json TEXT NOT NULL DEFAULT '{}',
  image_object_key TEXT,
  source TEXT,
  source_id TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE care_profiles (
  id TEXT PRIMARY KEY,
  species_id TEXT NOT NULL REFERENCES species(id),
  name TEXT NOT NULL,
  tasks_json TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE plants (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  garden_id TEXT NOT NULL,
  species_id TEXT,
  nickname TEXT,
  location_type TEXT,
  acquired_at INTEGER,
  planted_at INTEGER,
  archived_at INTEGER,
  last_watered_at INTEGER,
  next_water_check_at INTEGER,
  last_fertilized_at INTEGER,
  next_fertilize_at INTEGER,
  last_pest_check_at INTEGER,
  next_pest_check_at INTEGER,
  health TEXT,
  notes TEXT,
  revision INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE care_events (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  plant_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  note TEXT,
  details_json TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE reminders (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  plant_id TEXT NOT NULL,
  species_id TEXT,
  task_type TEXT NOT NULL,
  title TEXT NOT NULL,
  instructions TEXT,
  due_at INTEGER NOT NULL,
  status TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'normal',
  interval_days INTEGER,
  schedule_source TEXT NOT NULL DEFAULT 'user',
  completed_at INTEGER,
  snoozed_until INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE photos (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  plant_id TEXT NOT NULL,
  object_key TEXT NOT NULL,
  content_type TEXT NOT NULL,
  byte_size INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE device_tokens (
  token TEXT NOT NULL,
  user_id TEXT NOT NULL,
  platform TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, token)
);

CREATE TABLE notification_deliveries (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  reminder_id TEXT NOT NULL,
  due_at INTEGER NOT NULL,
  status TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE idempotency_keys (
  user_id TEXT NOT NULL,
  key TEXT NOT NULL,
  request_hash TEXT NOT NULL,
  status INTEGER NOT NULL,
  response_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, key)
);

CREATE TABLE write_rates (
  user_id TEXT NOT NULL,
  window_start INTEGER NOT NULL,
  hits INTEGER NOT NULL,
  PRIMARY KEY (user_id, window_start)
);
