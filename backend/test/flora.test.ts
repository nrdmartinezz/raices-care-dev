import { describe, expect, it } from "vitest";
import { careForName, careFromFlora, readPlantCare } from "../src/catalog/plant_care";
import { matchFloraHit } from "../src/catalog/flora";

const pepper = {
  id: 42,
  scientific_name: "Capsicum annuum",
  common_names: ["bell pepper"],
  taxonomic_rank: "species",
  usda_symbol: "CAAN7",
  light_requirements: ["Full sun"],
  soil_moisture: ["Dry"],
  water_use: ["Low"],
  maintenance_tasks: ["Fertilize monthly", "Check for pests weekly"],
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

describe("Flora name matching", () => {
  it("keeps an exact name and ignores an unrelated hit", () => {
    expect(
      matchFloraHit("bell pepper", [
        { id: 1, scientific_name: "Quercus alba", common_names: ["oak"] },
        pepper,
      ])?.id,
    ).toBe(42);
  });

  it("misses when no name matches", () => {
    expect(
      matchFloraHit("bell pepper", [
        { id: 1, scientific_name: "Quercus alba", common_names: ["oak"] },
      ]),
    ).toBeNull();
  });
});

describe("Flora care fallback", () => {
  it("maps water, light, and credit from a species profile", () => {
    const care = careFromFlora(pepper);
    const water = care.tasks.find((task) => task.taskType === "water_check");
    const feed = care.tasks.find((task) => task.taskType === "fertilize");
    const pest = care.tasks.find((task) => task.taskType === "pest_check");
    expect(water?.intervalDays).toBe(14);
    expect(water?.instructions).toBe("Water use: Low. Soil moisture: Dry.");
    expect(feed?.instructions).toBe("Fertilize monthly");
    expect(feed?.intervalDays).toBe(30);
    expect(pest?.instructions).toBe("Check for pests weekly");
    expect(care.light).toBe("Full sun");
    expect(care.difficulty).toBeNull();
    expect(care.sourceLabel).toBe("Flora");
    expect(care.sourceUrl).toBe("https://plants.usda.gov/plant-profile/CAAN7");
  });

  it("uses Flora only after PlantSolve misses", async () => {
    const calls: string[] = [];
    const fetchImpl = (async (input: RequestInfo | URL) => {
      const url = String(input);
      calls.push(url);
      if (url.includes("plantsolve.com") && url.endsWith("/index.json")) {
        return jsonResponse([{ slug: "monstera" }]);
      }
      if (url.includes("floraapi.com/v1/search")) {
        return jsonResponse({ results: [pepper] });
      }
      if (url.includes("floraapi.com/v1/species/42")) {
        return jsonResponse(pepper);
      }
      throw new Error(`unexpected ${url}`);
    }) as typeof fetch;

    const care = await careForName("bell pepper", { fetchImpl, floraApiKey: "test-key" });
    expect(care.sourceLabel).toBe("Flora");
    expect(care.tasks.find((task) => task.taskType === "water_check")?.intervalDays).toBe(14);
    expect(calls.some((url) => url.includes("floraapi.com"))).toBe(true);
  });

  it("does not call Flora when PlantSolve has the plant", async () => {
    const calls: string[] = [];
    const fetchImpl = (async (input: RequestInfo | URL) => {
      const url = String(input);
      calls.push(url);
      if (url.endsWith("/index.json")) return jsonResponse([{ slug: "monstera" }]);
      if (url.endsWith("/monstera.json")) {
        return jsonResponse({
          care: { difficulty: "easy", watering: "Let the top inch dry." },
          lighting: { description: "Bright indirect light." },
        });
      }
      throw new Error(`unexpected ${url}`);
    }) as typeof fetch;

    const care = await careForName("monstera", { fetchImpl, floraApiKey: "test-key" });
    expect(care.sourceLabel).toBe("PlantSolve");
    expect(calls.some((url) => url.includes("floraapi.com"))).toBe(false);
  });

  it("keeps the defaults when the Flora key is missing", async () => {
    const fetchImpl = (async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes("plantsolve.com") && url.endsWith("/index.json")) {
        return jsonResponse([]);
      }
      throw new Error(`unexpected ${url}`);
    }) as typeof fetch;

    const care = await careForName("bell pepper", { fetchImpl });
    expect(care.sourceLabel).toBeNull();
    expect(care.sourceUrl).toBeNull();
    expect(care.tasks.map((task) => task.intervalDays)).toEqual([7, 30, 14]);
  });

  it("does not use a search hit that does not name the query", async () => {
    const fetchImpl = (async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes("plantsolve.com")) return jsonResponse([]);
      if (url.includes("floraapi.com/v1/search")) {
        return jsonResponse({
          results: [{ id: 1, scientific_name: "Quercus alba", common_names: ["oak"] }],
        });
      }
      throw new Error(`unexpected ${url}`);
    }) as typeof fetch;

    const care = await careForName("bell pepper", { fetchImpl, floraApiKey: "test-key" });
    expect(care.sourceLabel).toBeNull();
    expect(care.light).toBeNull();
  });

  it("reads a PlantSolve link saved before source labels existed", () => {
    const care = readPlantCare(
      JSON.stringify({
        tasks: [],
        difficulty: null,
        light: null,
        sourceUrl: "https://www.plantsolve.com/plants/monstera",
      }),
    );
    expect(care.sourceLabel).toBe("PlantSolve");
  });
});
