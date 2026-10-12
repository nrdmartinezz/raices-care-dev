-- Per-plant edits. The species row stays the catalog copy.
ALTER TABLE plants ADD COLUMN scientific_name TEXT;
ALTER TABLE plants ADD COLUMN growing_method TEXT;
ALTER TABLE plants ADD COLUMN age_from INTEGER;
ALTER TABLE plants ADD COLUMN cover_photo_id TEXT;
ALTER TABLE plants ADD COLUMN care_guide_json TEXT;

CREATE TABLE journal_entries (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  plant_id TEXT NOT NULL,
  note TEXT NOT NULL,
  observed_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE INDEX journal_entries_plant
  ON journal_entries (user_id, plant_id, observed_at);
