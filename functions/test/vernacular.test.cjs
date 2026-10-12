const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeVernacular,
  lookupGardenName,
  mergeBySlug,
  pinAliasSpecies,
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

test("jalapeno pins Capsicum annuum and drops the rest of that page", () => {
  const page = [
    {
      slug: "capsicum-annuum",
      common_name: "pepper",
      scientific_name: "Capsicum annuum",
      rank: "species",
    },
    {
      slug: "capsicum-annuum-glabriusculum",
      common_name: "chiltepin",
      scientific_name: "Capsicum annuum var. glabriusculum",
      rank: "variety",
    },
    {
      slug: "capsicum-chinense",
      common_name: "habanero",
      scientific_name: "Capsicum chinense",
      rank: "species",
    },
  ];

  const pinned = pinAliasSpecies(page, "Capsicum annuum");
  assert.deepEqual(
    pinned.map((match) => match.slug),
    ["capsicum-annuum"],
  );

  const merged = mergeBySlug(
    pinned,
    [
      {
        slug: "capsicum-annuum",
        common_name: "jalapeno",
        scientific_name: "Capsicum annuum",
        rank: "species",
      },
      {
        slug: "capsicum-annuum-jalapeno",
        common_name: "jalapeno",
        scientific_name: "Capsicum annuum 'Jalapeno'",
        rank: "variety",
      },
    ],
    "jalapeno",
  );
  assert.deepEqual(
    merged.map((match) => [match.slug, match.common_name]),
    [
      ["capsicum-annuum", "jalapeno"],
      ["capsicum-annuum-jalapeno", "jalapeno"],
    ],
  );

  const bellPepper = mergeBySlug(pinned, [], "bell pepper");
  assert.deepEqual(
    bellPepper.map((match) => [match.slug, match.common_name]),
    [["capsicum-annuum", "bell pepper"]],
  );
  assert.equal(pinAliasSpecies(page.slice(1), "Capsicum annuum").length, 0);
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
