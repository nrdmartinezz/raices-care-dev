CREATE INDEX plants_user_updated ON plants (user_id, updated_at DESC, id);
CREATE INDEX plants_user_garden ON plants (user_id, garden_id);
CREATE INDEX reminders_user_due ON reminders (user_id, status, due_at);
CREATE INDEX reminders_plant ON reminders (plant_id, task_type);
CREATE INDEX care_events_plant_time ON care_events (plant_id, occurred_at DESC);
CREATE INDEX photos_plant ON photos (plant_id, created_at DESC);
CREATE INDEX gardens_user ON gardens (user_id, updated_at DESC);
CREATE UNIQUE INDEX notification_deliveries_once
  ON notification_deliveries (user_id, reminder_id, due_at);

CREATE VIRTUAL TABLE species_fts USING fts5(
  species_id UNINDEXED,
  scientific_name,
  common_names
);

CREATE TRIGGER species_fts_insert AFTER INSERT ON species BEGIN
  INSERT INTO species_fts (species_id, scientific_name, common_names)
  VALUES (
    new.id,
    new.scientific_name,
    new.common_names_json
  );
END;

CREATE TRIGGER species_fts_delete AFTER DELETE ON species BEGIN
  DELETE FROM species_fts WHERE species_id = old.id;
END;

CREATE TRIGGER species_fts_update AFTER UPDATE ON species BEGIN
  DELETE FROM species_fts WHERE species_id = old.id;
  INSERT INTO species_fts (species_id, scientific_name, common_names)
  VALUES (
    new.id,
    new.scientific_name,
    new.common_names_json
  );
END;
