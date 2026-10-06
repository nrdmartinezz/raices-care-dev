-- Local development catalog only. Not a migration, so it is not applied remotely.
INSERT INTO species (
  id, scientific_name, common_names_json, plant_groups_json, toxicity_json,
  source, source_id, created_at, updated_at
) VALUES
(
  'monstera-deliciosa',
  'Monstera deliciosa',
  '["Swiss cheese plant","split-leaf philodendron"]',
  '["tropical","houseplant"]',
  '{"pets":"toxic","notes":"Calcium oxalate crystals."}',
  'sample',
  'monstera-deliciosa',
  0,
  0
),
(
  'ocimum-basilicum',
  'Ocimum basilicum',
  '["basil","sweet basil"]',
  '["herb","vegetable"]',
  '{}',
  'sample',
  'ocimum-basilicum',
  0,
  0
),
(
  'solanum-lycopersicum',
  'Solanum lycopersicum',
  '["tomato"]',
  '["vegetable","fruiting"]',
  '{"pets":"toxic","notes":"Leaves and stems are toxic."}',
  'sample',
  'solanum-lycopersicum',
  0,
  0
);

INSERT INTO care_profiles (id, species_id, name, tasks_json, created_at, updated_at) VALUES
(
  'monstera-deliciosa-default',
  'monstera-deliciosa',
  'Indoor default',
  '[{"taskType":"water_check","title":"Check water","intervalDays":7,"instructions":"Water when the top few centimeters of soil are dry.","priority":"normal"},{"taskType":"fertilize","title":"Fertilize","intervalDays":30,"instructions":"Feed during active growth.","priority":"low"},{"taskType":"pest_check","title":"Check for pests","intervalDays":14,"priority":"normal"}]',
  0,
  0
),
(
  'ocimum-basilicum-default',
  'ocimum-basilicum',
  'Herb default',
  '[{"taskType":"water_check","title":"Check water","intervalDays":2,"instructions":"Keep the soil evenly moist.","priority":"high"},{"taskType":"harvest","title":"Harvest","intervalDays":7,"instructions":"Pinch stems above a leaf pair.","priority":"normal"}]',
  0,
  0
),
(
  'solanum-lycopersicum-default',
  'solanum-lycopersicum',
  'Garden default',
  '[{"taskType":"water_check","title":"Check water","intervalDays":3,"instructions":"Water deeply at the soil line.","priority":"high"},{"taskType":"fertilize","title":"Fertilize","intervalDays":14,"priority":"normal"},{"taskType":"pest_check","title":"Check for pests","intervalDays":7,"priority":"normal"}]',
  0,
  0
);
