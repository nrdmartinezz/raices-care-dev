const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeVernacular,
  lookupGardenName,
  mergeBySlug,
} = require("../lib/catalog/vernacular");

test("normalize strips accents and punctuation", () => {
  assert.equal(normalizeVernacular("  Albahaca "), "albahaca");
  assert.equal(normalizeVernacular("snake-plant"), "snake plant");
  assert.equal(
    normalizeVernacular("mother-in-law's tongue"),
    "mother in law s tongue",
  );
});

test("garden names resolve to one scientific name", () => {
  assert.equal(lookupGardenName("albahaca"), "Ocimum basilicum");
  assert.equal(lookupGardenName("basil"), "Ocimum basilicum");
  assert.equal(lookupGardenName("snake plant"), "Dracaena trifasciata");
  assert.equal(lookupGardenName("jitomate"), "Solanum lycopersicum");
  assert.equal(lookupGardenName("tomate"), "Solanum lycopersicum");
  assert.equal(lookupGardenName("no such plant"), null);
});

test("alias hits stay ahead of the direct search and keep a typed name", () => {
  const alias = [
    {
      slug: "dracaena-trifasciata",
      common_name: null,
      scientific_name: "Dracaena trifasciata",
    },
    {
      slug: "dracaena-angolensis",
      common_name: null,
      scientific_name: "Dracaena angolensis",
    },
  ];
  const direct = [
    {
      slug: "dracaena-trifasciata",
      common_name: null,
      scientific_name: "Dracaena trifasciata",
    },
    {
      slug: "sansevieria",
      common_name: "snake plant",
      scientific_name: "Sansevieria",
    },
  ];

  const merged = mergeBySlug(alias, direct, "snake plant");
  assert.deepEqual(
    merged.map((match) => [match.slug, match.common_name]),
    [
      ["dracaena-trifasciata", "snake plant"],
      ["dracaena-angolensis", null],
      ["sansevieria", "snake plant"],
    ],
  );
});
