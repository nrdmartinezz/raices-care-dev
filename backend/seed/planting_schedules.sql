-- Authored sowing windows. Offsets are days from the average last spring
-- freeze or the average first fall freeze. They are not read from Trefle.
-- Cool crops repeat across seasons as extra plans on the same row.

INSERT INTO planting_schedules (
  id, species_id, scientific_name, common_name, match_names_json,
  days_to_harvest, overwinters, windows_json
) VALUES
(
  'lactuca-sativa', 'lactuca-sativa', 'Lactuca sativa', 'Lettuce',
  '["lettuce","lactuca sativa"]', 45, 0,
  '[{"season":"spring","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-28,"endOffsetDays":-7}]},{"season":"fall","milestones":[{"method":"direct_sow","anchor":"first_fall_frost","startOffsetDays":-60,"endOffsetDays":-35}]},{"season":"winter","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-100,"endOffsetDays":-70}]}]'
),
(
  'spinacia-oleracea', 'spinacia-oleracea', 'Spinacia oleracea', 'Spinach',
  '["spinach","spinacia oleracea"]', 40, 0,
  '[{"season":"spring","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-42,"endOffsetDays":-14}]},{"season":"fall","milestones":[{"method":"direct_sow","anchor":"first_fall_frost","startOffsetDays":-55,"endOffsetDays":-30}]}]'
),
(
  'pisum-sativum', 'pisum-sativum', 'Pisum sativum', 'Pea',
  '["pea","garden pea","pisum sativum"]', 60, 0,
  '[{"season":"spring","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-42,"endOffsetDays":-14}]}]'
),
(
  'brassica-oleracea-kale', 'brassica-oleracea-kale', 'Brassica oleracea', 'Kale',
  '["kale","brassica oleracea","brassica oleracea var. sabellica","brassica oleracea var. acephala"]', 55, 0,
  '[{"season":"spring","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-56,"endOffsetDays":-42},{"method":"transplant","anchor":"last_spring_frost","startOffsetDays":-21,"endOffsetDays":-7}]},{"season":"fall","milestones":[{"method":"direct_sow","anchor":"first_fall_frost","startOffsetDays":-90,"endOffsetDays":-60}]}]'
),
(
  'raphanus-sativus', 'raphanus-sativus', 'Raphanus sativus', 'Radish',
  '["radish","raphanus sativus"]', 28, 0,
  '[{"season":"spring","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-28,"endOffsetDays":0}]},{"season":"fall","milestones":[{"method":"direct_sow","anchor":"first_fall_frost","startOffsetDays":-40,"endOffsetDays":-21}]}]'
),
(
  'brassica-oleracea-italica', 'brassica-oleracea-italica', 'Brassica oleracea', 'Broccoli',
  '["broccoli","brassica oleracea","brassica oleracea var. italica"]', 70, 0,
  '[{"season":"spring","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-70,"endOffsetDays":-56},{"method":"transplant","anchor":"last_spring_frost","startOffsetDays":-21,"endOffsetDays":0}]},{"season":"fall","milestones":[{"method":"transplant","anchor":"first_fall_frost","startOffsetDays":-100,"endOffsetDays":-75}]}]'
),
(
  'daucus-carota', 'daucus-carota', 'Daucus carota', 'Carrot',
  '["carrot","daucus carota","daucus carota subsp. sativus"]', 70, 0,
  '[{"season":"spring","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-21,"endOffsetDays":7}]},{"season":"fall","milestones":[{"method":"direct_sow","anchor":"first_fall_frost","startOffsetDays":-85,"endOffsetDays":-60}]}]'
),
(
  'coriandrum-sativum', 'coriandrum-sativum', 'Coriandrum sativum', 'Cilantro',
  '["cilantro","coriander","coriandrum sativum"]', 45, 0,
  '[{"season":"spring","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-14,"endOffsetDays":14}]},{"season":"fall","milestones":[{"method":"direct_sow","anchor":"first_fall_frost","startOffsetDays":-60,"endOffsetDays":-35}]}]'
),
(
  'beta-vulgaris-cicla', 'beta-vulgaris-cicla', 'Beta vulgaris', 'Chard',
  '["chard","swiss chard","beta vulgaris","beta vulgaris subsp. cicla","beta vulgaris var. cicla"]', 55, 0,
  '[{"season":"spring","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-14,"endOffsetDays":14}]},{"season":"fall","milestones":[{"method":"direct_sow","anchor":"first_fall_frost","startOffsetDays":-70,"endOffsetDays":-45}]}]'
),
(
  'beta-vulgaris', 'beta-vulgaris', 'Beta vulgaris', 'Beet',
  '["beet","beetroot","beta vulgaris","beta vulgaris subsp. vulgaris"]', 55, 0,
  '[{"season":"spring","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-21,"endOffsetDays":7}]},{"season":"fall","milestones":[{"method":"direct_sow","anchor":"first_fall_frost","startOffsetDays":-75,"endOffsetDays":-50}]}]'
),
(
  'solanum-lycopersicum', 'solanum-lycopersicum', 'Solanum lycopersicum', 'Tomato',
  '["tomato","solanum lycopersicum"]', 75, 0,
  '[{"season":"summer","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-63,"endOffsetDays":-49},{"method":"transplant","anchor":"last_spring_frost","startOffsetDays":7,"endOffsetDays":21}]}]'
),
(
  'capsicum-annuum', 'capsicum-annuum', 'Capsicum annuum', 'Pepper',
  '["pepper","bell pepper","capsicum annuum"]', 70, 0,
  '[{"season":"summer","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-70,"endOffsetDays":-56},{"method":"transplant","anchor":"last_spring_frost","startOffsetDays":14,"endOffsetDays":28}]}]'
),
(
  'ocimum-basilicum', 'ocimum-basilicum', 'Ocimum basilicum', 'Basil',
  '["basil","sweet basil","ocimum basilicum"]', 60, 0,
  '[{"season":"summer","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-42,"endOffsetDays":-28},{"method":"transplant","anchor":"last_spring_frost","startOffsetDays":7,"endOffsetDays":21}]}]'
),
(
  'cucumis-sativus', 'cucumis-sativus', 'Cucumis sativus', 'Cucumber',
  '["cucumber","cucumis sativus"]', 55, 0,
  '[{"season":"summer","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":14,"endOffsetDays":28}]}]'
),
(
  'cucurbita-pepo', 'cucurbita-pepo', 'Cucurbita pepo', 'Zucchini',
  '["zucchini","courgette","summer squash","cucurbita pepo"]', 50, 0,
  '[{"season":"summer","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":14,"endOffsetDays":28}]}]'
),
(
  'phaseolus-vulgaris', 'phaseolus-vulgaris', 'Phaseolus vulgaris', 'Bush bean',
  '["bush bean","common bean","green bean","phaseolus vulgaris"]', 55, 0,
  '[{"season":"summer","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":7,"endOffsetDays":21}]}]'
),
(
  'solanum-melongena', 'solanum-melongena', 'Solanum melongena', 'Eggplant',
  '["eggplant","aubergine","solanum melongena"]', 80, 0,
  '[{"season":"summer","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-70,"endOffsetDays":-56},{"method":"transplant","anchor":"last_spring_frost","startOffsetDays":14,"endOffsetDays":28}]}]'
),
(
  'zea-mays', 'zea-mays', 'Zea mays', 'Corn',
  '["corn","sweet corn","maize","zea mays"]', 80, 0,
  '[{"season":"summer","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":14,"endOffsetDays":28}]}]'
),
(
  'abelmoschus-esculentus', 'abelmoschus-esculentus', 'Abelmoschus esculentus', 'Okra',
  '["okra","abelmoschus esculentus"]', 60, 0,
  '[{"season":"summer","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":21,"endOffsetDays":35}]}]'
),
(
  'cucumis-melo', 'cucumis-melo', 'Cucumis melo', 'Melon',
  '["melon","cantaloupe","muskmelon","cucumis melo"]', 80, 0,
  '[{"season":"summer","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":14,"endOffsetDays":28}]}]'
),
(
  'allium-sativum', 'allium-sativum', 'Allium sativum', 'Garlic',
  '["garlic","allium sativum"]', 240, 1,
  '[{"season":"fall","milestones":[{"method":"direct_sow","anchor":"first_fall_frost","startOffsetDays":-21,"endOffsetDays":14}]}]'
),
(
  'brassica-rapa', 'brassica-rapa', 'Brassica rapa', 'Turnip',
  '["turnip","brassica rapa"]', 45, 0,
  '[{"season":"fall","milestones":[{"method":"direct_sow","anchor":"first_fall_frost","startOffsetDays":-60,"endOffsetDays":-35}]}]'
),
(
  'allium-cepa', 'allium-cepa', 'Allium cepa', 'Onion',
  '["onion","allium cepa"]', 100, 0,
  '[{"season":"winter","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-84,"endOffsetDays":-70},{"method":"transplant","anchor":"last_spring_frost","startOffsetDays":-28,"endOffsetDays":-14}]}]'
),
(
  'allium-ampeloprasum', 'allium-ampeloprasum', 'Allium ampeloprasum', 'Leek',
  '["leek","allium ampeloprasum"]', 120, 0,
  '[{"season":"winter","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-84,"endOffsetDays":-70},{"method":"transplant","anchor":"last_spring_frost","startOffsetDays":-14,"endOffsetDays":0}]}]'
),
(
  'apium-graveolens', 'apium-graveolens', 'Apium graveolens', 'Celery',
  '["celery","apium graveolens"]', 110, 0,
  '[{"season":"winter","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-84,"endOffsetDays":-70},{"method":"transplant","anchor":"last_spring_frost","startOffsetDays":7,"endOffsetDays":21}]}]'
),
(
  'petroselinum-crispum', 'petroselinum-crispum', 'Petroselinum crispum', 'Parsley',
  '["parsley","petroselinum crispum"]', 75, 0,
  '[{"season":"winter","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-70,"endOffsetDays":-49},{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-21,"endOffsetDays":0}]}]'
),
(
  'vicia-faba', 'vicia-faba', 'Vicia faba', 'Fava bean',
  '["fava bean","broad bean","vicia faba"]', 85, 0,
  '[{"season":"winter","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-56,"endOffsetDays":-28}]}]'
),
(
  'allium-cepa-shallot', 'allium-cepa-shallot', 'Allium cepa', 'Shallot',
  '["shallot","allium cepa var. aggregatum","allium cepa"]', 90, 0,
  '[{"season":"winter","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-28,"endOffsetDays":-7}]}]'
),
(
  'brassica-oleracea-capitata', 'brassica-oleracea-capitata', 'Brassica oleracea', 'Cabbage',
  '["cabbage","brassica oleracea","brassica oleracea var. capitata"]', 75, 0,
  '[{"season":"winter","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-70,"endOffsetDays":-56},{"method":"transplant","anchor":"last_spring_frost","startOffsetDays":-21,"endOffsetDays":0}]}]'
),
(
  'brassica-oleracea-gongylodes', 'brassica-oleracea-gongylodes', 'Brassica oleracea', 'Kohlrabi',
  '["kohlrabi","brassica oleracea","brassica oleracea var. gongylodes"]', 50, 0,
  '[{"season":"winter","milestones":[{"method":"start_indoors","anchor":"last_spring_frost","startOffsetDays":-56,"endOffsetDays":-42},{"method":"transplant","anchor":"last_spring_frost","startOffsetDays":-21,"endOffsetDays":-7}]}]'
),
(
  'brassica-juncea', 'brassica-juncea', 'Brassica juncea', 'Mustard',
  '["mustard","mustard greens","brassica juncea"]', 40, 0,
  '[{"season":"winter","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-42,"endOffsetDays":-14}]}]'
);
