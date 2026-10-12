import { describe, expect, it } from "vitest";
import { careForName, careFromProfile, readPlantCare } from "../src/catalog/plant_care";
import { matchPlantSolveSlug } from "../src/catalog/plantsolve";

const slugs = [
  "monstera",
  "monstera-albo",
  "african-violet",
  "golden-pothos-care",
];

describe("PlantSolve name matching", () => {
  it("matches a spaced name to its slug", () => {
    expect(matchPlantSolveSlug("african violet", slugs)).toBe("african-violet");
  });

  it("keeps the exact slug when a longer name is also listed", () => {
    expect(matchPlantSolveSlug("monstera", slugs)).toBe("monstera");
  });

  it("ignores a trailing care suffix on the slug", () => {
    expect(matchPlantSolveSlug("golden pothos", slugs)).toBe("golden-pothos-care");
  });

  it("misses a name the catalog does not list", () => {
    expect(matchPlantSolveSlug("bell pepper", slugs)).toBeNull();
  });
});

describe("PlantSolve care tips", () => {
  it("copies tips onto the default chores and keeps their intervals", () => {
    const care = careFromProfile(
      {
        care: {
          difficulty: "intermediate",
          watering: "Bottom-water only when the top inch of soil is dry.",
        },
        lighting: { description: "Bright, indirect light." },
        nutrients: { fertilizerFrequency: "Every two weeks during spring and summer." },
        relationships: [
          { type: "companion", notes: "Ignore this.", strength: 9 },
          { type: "vulnerability", notes: "Mild issue.", strength: 2 },
          {
            type: "vulnerability",
            notes: "Highly susceptible to crown rot.",
            strength: 9,
          },
        ],
      },
      "african-violet",
    );

    expect(care.tasks.map((task) => [task.taskType, task.intervalDays, task.instructions])).toEqual([
      ["water_check", 7, "Bottom-water only when the top inch of soil is dry."],
      ["fertilize", 30, "Every two weeks during spring and summer."],
      ["pest_check", 14, "Highly susceptible to crown rot."],
    ]);
    expect(care.difficulty).toBe("intermediate");
    expect(care.light).toBe("Bright, indirect light.");
    expect(care.sourceUrl).toBe("https://www.plantsolve.com/plants/african-violet");
    expect(care.sourceLabel).toBe("PlantSolve");
  });

  it("returns the defaults when the lookup misses", async () => {
    const fetchImpl = (async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.endsWith("/index.json")) {
        return Response.json([{ slug: "monstera" }]);
      }
      throw new Error(`unexpected ${url}`);
    }) as typeof fetch;

    const care = await careForName("bell pepper", { fetchImpl });
    expect(care.tasks.map((task) => [task.taskType, task.intervalDays])).toEqual([
      ["water_check", 7],
      ["fertilize", 30],
      ["pest_check", 14],
    ]);
    expect(care.difficulty).toBeNull();
    expect(care.light).toBeNull();
    expect(care.sourceUrl).toBeNull();
  });

  it("reads an older task array as tasks only", () => {
    const care = readPlantCare(
      JSON.stringify([
        {
          taskType: "water_check",
          title: "Check soil moisture",
          instructions: "Saved earlier.",
          intervalDays: 4,
          priority: "normal",
          basis: [],
        },
      ]),
    );
    expect(care.tasks).toHaveLength(1);
    expect(care.tasks[0]?.intervalDays).toBe(4);
    expect(care.difficulty).toBeNull();
    expect(care.sourceUrl).toBeNull();
  });
});
