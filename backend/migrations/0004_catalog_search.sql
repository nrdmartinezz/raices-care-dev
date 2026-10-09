ALTER TABLE species ADD COLUMN image_url TEXT;

CREATE TABLE vernacular_aliases (
  normalized_name TEXT PRIMARY KEY,
  scientific_name TEXT NOT NULL,
  source TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
