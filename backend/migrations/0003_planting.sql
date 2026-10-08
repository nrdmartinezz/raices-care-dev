-- Frost normals and authored sowing windows. Timestamps are not stored:
-- the dates are climate normals, and the windows are offsets from them.

CREATE TABLE frost_stations (
  id TEXT PRIMARY KEY,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  last_spring_doy INTEGER NOT NULL,
  first_fall_doy INTEGER NOT NULL,
  source TEXT NOT NULL
);

CREATE INDEX frost_stations_lat ON frost_stations (latitude);

CREATE TABLE planting_schedules (
  id TEXT PRIMARY KEY,
  species_id TEXT,
  scientific_name TEXT NOT NULL,
  common_name TEXT NOT NULL,
  match_names_json TEXT NOT NULL DEFAULT '[]',
  days_to_harvest INTEGER,
  overwinters INTEGER NOT NULL DEFAULT 0,
  windows_json TEXT NOT NULL
);

CREATE INDEX planting_schedules_scientific
  ON planting_schedules (scientific_name);
