import { env } from "cloudflare:test";
import { beforeAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app";
import {
  applicableRules,
  renderCarePlan,
  selectCareProfile,
  type CareProfileRecord,
  type CareRuleRecord,
  type PlantCareContext,
} from "../src/catalog/care_rules";
import { buildCareSql, validateCareBundle, type CareBundle } from "../src/catalog/care_import";
import type { Env } from "../src/env";

let app: ReturnType<typeof createApp>;

beforeAll(() => {
  app = createApp();
});

function call(path: string, init: RequestInit = {}, bindings: Env = env) {
  return app.request(path, init, bindings);
}

function dev(userId: string, init: RequestInit = {}): RequestInit {
  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer dev:${userId}`);
  return { ...init, headers };
}

function profile(
  id: string,
  appliesTo: CareProfileRecord["appliesTo"],
  version = 1,
): CareProfileRecord {
  return {
    id,
    name: id,
    appliesTo,
    status: "published",
    version,
    tasksJson: "[]",
  };
}

function rule(
  id: string,
  taskType: string,
  body: CareRuleRecord["rule"],
  displayOrder = 0,
): CareRuleRecord {
  return {
    id,
    careProfileId: "profile",
    taskType,
    rule: body,
    displayOrder,
    status: "published",
  };
}

const context = (locationType: string, growingMethod = "container"): PlantCareContext => ({
  locationType,
  growingMethod,
  sunlight: "bright_indirect",
  hardinessZone: "8b",
  newlyPlanted: false,
});

describe("care profile selection", () => {
  const indoor = profile("crassula-ovata-indoor", {
    location: ["indoor"],
    growingMethod: ["container"],
  });
  const outdoor = profile("crassula-ovata-outdoor", {
    location: ["outdoor"],
    growingMethod: ["container"],
  });

  it("selects indoor container care for an indoor plant", () => {
    const selected = selectCareProfile([outdoor, indoor], context("indoor"), indoor.id);
    expect(selected?.id).toBe(indoor.id);
  });

  it("uses the summer rule in summer and the dormant rule in winter", () => {
    const rules = [
      rule("general", "water_check", { strategy: "condition_based", checkEveryDays: 14 }, 2),
      rule("summer", "water_check", { season: "summer", strategy: "condition_based", checkEveryDays: 7 }, 0),
      rule("dormant", "fertilize", { season: "dormant", checkEveryDays: 90 }, 1),
    ];
    expect(applicableRules(rules, new Date("2026-07-15T00:00:00Z")).map((item) => item.id)).toEqual([
      "summer",
    ]);
    expect(applicableRules(rules, new Date("2026-01-15T00:00:00Z")).map((item) => item.id)).toEqual([
      "dormant",
      "general",
    ]);
  });

  it("omits the zone line indoors and states colder, in range, and warmer outdoors", () => {
    const outdoorProfile = profile("outdoor", { location: ["outdoor"], zoneMin: "9a", zoneMax: "11b" });
    const rules = [
      rule("water", "water_check", {
        strategy: "condition_based",
        primaryTrigger: "soil_dry",
        checkEveryDays: 7,
        zoneMin: "9a",
        zoneMax: "11b",
      }),
    ];
    const planFor = (locationType: string, hardinessZone: string) =>
      renderCarePlan({
        profile: outdoorProfile,
        rules,
        context: { ...context(locationType), hardinessZone },
        at: new Date("2026-10-12T00:00:00Z"),
      });
    expect(planFor("indoor", "6b").zone).toBeNull();
    expect(planFor("greenhouse", "6b").zone).toBeNull();
    expect(planFor("outdoor", "10a").zone?.result).toBe("in_range");
    expect(planFor("outdoor", "6b").zone?.result).toBe("colder");
    expect(planFor("outdoor", "12a").zone?.result).toBe("warmer");
  });
});

describe("care import", () => {
  const source = {
    id: "usda-plants",
    name: "USDA PLANTS",
    url: "https://plants.usda.gov",
    license: "public-domain",
    retrievedAt: 1760227200000,
  };

  it("rejects a water rule with no trigger and a profile whose species is missing", () => {
    const bundle: CareBundle = {
      species: [],
      profiles: [
        {
          id: "orphan",
          speciesId: "missing-species",
          name: "Indoor",
          appliesToJson: "{}",
          status: "published",
          version: 1,
          reviewedAt: 1760227200000,
          sourceRefs: ["usda-plants"],
        },
      ],
      rules: [
        {
          id: "water",
          careProfileId: "orphan",
          taskType: "water_check",
          ruleJson: JSON.stringify({ strategy: "condition_based" }),
          displayOrder: 0,
          status: "published",
        },
      ],
      sources: [source],
    };
    const messages = validateCareBundle(bundle).map((error) => error.message);
    expect(messages).toContain("Profile references a missing species.");
    expect(messages).toContain("Water rule needs a valid trigger.");
  });

  it("writes published profiles and leaves drafts out", () => {
    const bundle: CareBundle = {
      species: [
        {
          id: "crassula-ovata",
          scientificName: "Crassula ovata",
          primaryCommonName: "Jade plant",
          defaultCareProfileId: "published-profile",
          status: "published",
          aliases: [],
        },
      ],
      profiles: [
        {
          id: "published-profile",
          speciesId: "crassula-ovata",
          name: "Indoor",
          appliesToJson: "{}",
          status: "published",
          version: 1,
          reviewedAt: 1760227200000,
          sourceRefs: ["usda-plants"],
        },
        {
          id: "draft-profile",
          speciesId: "crassula-ovata",
          name: "Draft",
          appliesToJson: "{}",
          status: "draft",
          version: 1,
          reviewedAt: null,
          sourceRefs: [],
        },
      ],
      rules: [],
      sources: [source],
    };
    expect(validateCareBundle(bundle)).toEqual([]);
    const sql = buildCareSql(bundle);
    expect(sql).toContain("published-profile");
    expect(sql).not.toContain("draft-profile");
  });
});

describe("generated care plans", () => {
  it("snapshots the profile version and the outdoor zone", async () => {
    const ts = Date.now();
    await env.DB.prepare(
      `INSERT INTO species (
        id, scientific_name, common_names_json, plant_groups_json, toxicity_json,
        created_at, updated_at, primary_common_name, default_care_profile_id, status
      ) VALUES ('crassula-ovata', 'Crassula ovata', '["Jade plant"]', '[]', '{}', ?, ?, 'Jade plant', 'crassula-indoor', 'published')`,
    )
      .bind(ts, ts)
      .run();
    await env.DB.batch([
      env.DB.prepare(
        `INSERT INTO care_profiles (
          id, species_id, name, tasks_json, created_at, updated_at,
          applies_to_json, status, version, reviewed_at, source_refs_json
        ) VALUES ('crassula-indoor', 'crassula-ovata', 'Indoor container care', '[]', ?, ?, ?, 'published', 1, ?, '[]')`,
      ).bind(
        ts,
        ts,
        JSON.stringify({ location: ["indoor"], growingMethod: ["container"] }),
        ts,
      ),
      env.DB.prepare(
        `INSERT INTO care_profiles (
          id, species_id, name, tasks_json, created_at, updated_at,
          applies_to_json, status, version, reviewed_at, source_refs_json
        ) VALUES ('crassula-outdoor', 'crassula-ovata', 'Outdoor container care', '[]', ?, ?, ?, 'published', 3, ?, '[]')`,
      ).bind(
        ts,
        ts,
        JSON.stringify({ location: ["outdoor"], growingMethod: ["container"] }),
        ts,
      ),
      env.DB.prepare(
        `INSERT INTO care_rules (id, care_profile_id, task_type, rule_json, display_order, status)
         VALUES ('crassula-indoor-water', 'crassula-indoor', 'water_check', ?, 0, 'published')`,
      ).bind(
        JSON.stringify({
          strategy: "condition_based",
          primaryTrigger: "soil_dry",
          checkEveryDays: 14,
          instructions: "Water thoroughly only when the potting mix has dried fully.",
        }),
      ),
      env.DB.prepare(
        `INSERT INTO care_rules (id, care_profile_id, task_type, rule_json, display_order, status)
         VALUES ('crassula-outdoor-water', 'crassula-outdoor', 'water_check', ?, 0, 'published')`,
      ).bind(
        JSON.stringify({
          strategy: "condition_based",
          primaryTrigger: "top_soil_dry",
          checkEveryDays: 7,
          zoneMin: "9a",
          zoneMax: "11b",
          instructions: "Check moisture more often outdoors.",
        }),
      ),
    ]);

    expect(
      (
        await call(
          "/v1/gardens",
          dev("zone-grower", {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({ id: "garden-zone", name: "Yard" }),
          }),
        )
      ).status,
    ).toBe(201);

    async function addPlant(id: string, locationType: string, hardinessZone: string) {
      const response = await call(
        "/v1/plants",
        dev("zone-grower", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            id,
            gardenId: "garden-zone",
            speciesId: "crassula-ovata",
            locationType,
            growingMethod: "container",
            hardinessZone,
          }),
        }),
      );
      expect(response.status).toBe(201);
      return response.json() as Promise<{ careProfileId: string }>;
    }

    const indoor = await addPlant("jade-indoor", "indoor", "6b");
    expect(indoor.careProfileId).toBe("crassula-indoor");
    const colder = await addPlant("jade-cold", "outdoor", "6b");
    const ranged = await addPlant("jade-range", "outdoor", "10a");
    const warmer = await addPlant("jade-warm", "outdoor", "12a");
    expect(colder.careProfileId).toBe("crassula-outdoor");
    expect(ranged.careProfileId).toBe("crassula-outdoor");
    expect(warmer.careProfileId).toBe("crassula-outdoor");

    async function zoneResult(plantId: string) {
      const row = await env.DB.prepare(
        "SELECT profile_version, plan_json FROM plant_care_plans WHERE plant_id = ?",
      )
        .bind(plantId)
        .first<{ profile_version: number; plan_json: string }>();
      const plan = JSON.parse(row!.plan_json) as {
        zone: { result: string } | null;
        careProfileVersion: number;
      };
      return { version: row!.profile_version, plan };
    }

    expect((await zoneResult("jade-indoor")).plan.zone).toBeNull();
    expect((await zoneResult("jade-cold")).plan.zone?.result).toBe("colder");
    expect((await zoneResult("jade-range")).plan.zone?.result).toBe("in_range");
    expect((await zoneResult("jade-warm")).plan.zone?.result).toBe("warmer");

    await env.DB.prepare("UPDATE care_profiles SET version = 9 WHERE id = 'crassula-outdoor'").run();
    const kept = await zoneResult("jade-range");
    expect(kept.version).toBe(3);
    expect(kept.plan.careProfileVersion).toBe(3);
  });
});
