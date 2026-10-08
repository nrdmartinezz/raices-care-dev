import { env } from "cloudflare:test";
import { createLocalJWKSet, exportJWK, generateKeyPair, type CryptoKey } from "jose";
import { beforeAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app";
import type { Env } from "../src/env";
import {
  datedPlans,
  isInSeason,
  monthDayToDoy,
  nearestStation,
  parsePlans,
} from "../src/planting/calendar";

const tomatoWindows = JSON.stringify([
  {
    season: "summer",
    milestones: [
      {
        method: "start_indoors",
        anchor: "last_spring_frost",
        startOffsetDays: -63,
        endOffsetDays: -49,
      },
      {
        method: "transplant",
        anchor: "last_spring_frost",
        startOffsetDays: 7,
        endOffsetDays: 21,
      },
    ],
  },
]);

const frost = { lastSpringDoy: 89, firstFallDoy: 324 };

let app: ReturnType<typeof createApp>;

beforeAll(async () => {
  const pair = await generateKeyPair("RS256", { extractable: true });
  const jwk = await exportJWK(pair.publicKey as CryptoKey);
  jwk.alg = "RS256";
  jwk.kid = "test";
  app = createApp({ jwks: createLocalJWKSet({ keys: [jwk] }) });

  await env.DB.prepare(
    `INSERT INTO frost_stations (id, latitude, longitude, last_spring_doy, first_fall_doy, source)
     VALUES (?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      "USW00094728",
      40.7789,
      -73.9692,
      89,
      324,
      "noaa-ncei-1991-2020-t32-fp50",
      "NEAR",
      40.95,
      -74.2,
      110,
      290,
      "noaa-ncei-1991-2020-t32-fp50",
    )
    .run();

  await env.DB.prepare(
    `INSERT INTO planting_schedules (
       id, species_id, scientific_name, common_name, match_names_json,
       days_to_harvest, overwinters, windows_json
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      "solanum-lycopersicum",
      "solanum-lycopersicum",
      "Solanum lycopersicum",
      "Tomato",
      '["tomato","solanum lycopersicum"]',
      75,
      0,
      tomatoWindows,
      "brassica-oleracea-kale",
      "brassica-oleracea-kale",
      "Brassica oleracea",
      "Kale",
      '["kale","brassica oleracea"]',
      55,
      0,
      '[{"season":"spring","milestones":[{"method":"direct_sow","anchor":"last_spring_frost","startOffsetDays":-21,"endOffsetDays":-7}]}]',
    )
    .run();
});

function call(path: string) {
  return app.request(
    path,
    { headers: { Authorization: "Bearer dev:gardener" } },
    env as Env,
  );
}

describe("planting dates", () => {
  it("keeps March 30 on day 89 in a leap year", () => {
    expect(monthDayToDoy(3, 30)).toBe(89);
    const plans = parsePlans(tomatoWindows);
    expect(plans).not.toBeNull();
    const dated = datedPlans(plans!, frost, new Date(Date.UTC(2024, 0, 1)));
    expect(dated[0]?.milestones[0]).toMatchObject({
      method: "start_indoors",
      start: "2024-01-27",
      end: "2024-02-10",
    });
  });

  it("treats the two weeks before a window as in season", () => {
    const plans = parsePlans(tomatoWindows)!;
    expect(isInSeason(plans, frost, new Date(Date.UTC(2026, 0, 30)))).toBe(true);
    expect(isInSeason(plans, frost, new Date(Date.UTC(2026, 0, 16)))).toBe(true);
    expect(isInSeason(plans, frost, new Date(Date.UTC(2026, 0, 1)))).toBe(false);
  });

  it("picks the nearer station", () => {
    const chosen = nearestStation(
      [
        { id: "far", latitude: 41.2, longitude: -74.5 },
        { id: "near", latitude: 40.78, longitude: -73.97 },
      ],
      40.7789,
      -73.9692,
    );
    expect(chosen?.id).toBe("near");
  });
});

describe("planting routes", () => {
  it("returns this year's frost dates for the nearest station", async () => {
    const year = new Date().getUTCFullYear();
    const response = await call("/v1/planting/frost?lat=40.7789&lon=-73.9692");
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      lastSpringFrost: `${year}-03-30`,
      firstFallFrost: `${year}-11-20`,
      stationId: "USW00094728",
      label: "30-year averages",
    });
  });

  it("says when the frost calendar does not cover the point", async () => {
    const response = await call("/v1/planting/frost?lat=0&lon=-30");
    expect(response.status).toBe(404);
  });

  it("returns tomato sowing dates and leaves unknown plants unmarked", async () => {
    const calendar = await call(
      "/v1/planting/species?name=Solanum%20lycopersicum&lat=40.7789&lon=-73.9692",
    );
    expect(calendar.status).toBe(200);
    const body = await calendar.json();
    expect(body).toMatchObject({
      commonName: "Tomato",
      daysToHarvest: 75,
    });
    expect(body.plans[0].milestones[0].method).toBe("start_indoors");

    const season = await call(
      "/v1/planting/season?lat=40.7789&lon=-73.9692&names=Solanum%20lycopersicum,Monstera%20deliciosa",
    );
    expect(season.status).toBe(200);
    const results = (await season.json()).results;
    const plans = parsePlans(tomatoWindows)!;
    expect(results).toEqual([
      { name: "Solanum lycopersicum", inSeason: isInSeason(plans, frost, new Date()) },
      { name: "Monstera deliciosa", inSeason: null },
    ]);
  });

  it("uses the common name when several crops share a scientific name", async () => {
    const response = await call(
      "/v1/planting/species?name=Brassica%20oleracea&common=Kale&lat=40.7789&lon=-73.9692",
    );
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ commonName: "Kale" });
  });
});
