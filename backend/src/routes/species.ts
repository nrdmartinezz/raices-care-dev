import { Hono } from "hono";
import { z } from "zod";
import {
  CatalogHit,
  fetchAndStoreSpecies,
  findLocalSpeciesIds,
  isFresh,
  liveCatalogHits,
  loadCachedSpecies,
  requireTrefleToken,
  searchFilters,
} from "../catalog/search";
import type { AppEnv } from "../env";
import { parseBody, readObject } from "../http/body";
import { pageLimit } from "../http/cursor";
import { ApiError } from "../http/errors";
import { iso, readJson } from "../http/ids";

export const speciesRoutes = new Hono<AppEnv>();

type SpeciesRow = {
  id: string;
  scientific_name: string;
  common_names_json: string;
  plant_groups_json: string;
  toxicity_json: string;
  image_object_key: string | null;
  image_url: string | null;
  source: string | null;
  source_id: string | null;
  updated_at: number;
};

function speciesJson(row: SpeciesRow, tasks: unknown[] = []) {
  return {
    id: row.id,
    scientificName: row.scientific_name,
    commonNames: readJson<string[]>(row.common_names_json, []),
    plantGroups: readJson<string[]>(row.plant_groups_json, []),
    toxicity: readJson<Record<string, unknown>>(row.toxicity_json, {}),
    hasImage: !!row.image_object_key || !!row.image_url,
    imageUrl:
      row.image_url ??
      (row.image_object_key ? `/v1/species/${row.id}/image` : null),
    trefleSlug: row.source_id,
    family: null,
    dataCompleteness: null,
    source: row.source,
    sourceId: row.source_id,
    updatedAt: iso(row.updated_at),
    careProfiles: tasks,
  };
}

speciesRoutes.get("/v1/species", async (c) => {
  const query = (c.req.query("q") ?? "").trim();
  const limit = pageLimit(c.req.query("limit"), 20);
  let ids: string[] = [];
  if (!query) {
    const listed = await c.env.DB.prepare(
      "SELECT id FROM species ORDER BY scientific_name LIMIT ?",
    )
      .bind(limit)
      .all<{ id: string }>();
    ids = (listed.results ?? []).map((row) => row.id);
  } else {
    const live =
      query.length >= 2
        ? await liveCatalogHits(
            c.env.DB,
            query,
            c.env.TREFLE_API_TOKEN,
            searchFilters({
              rank: c.req.query("rank"),
              family: c.req.query("family"),
              edible: c.req.query("edible"),
              vegetable: c.req.query("vegetable"),
            }),
          )
        : { hits: [], attribution: null, scientificName: null };
    const terms = [query];
    if (
      live.scientificName &&
      live.scientificName.toLowerCase() !== query.toLowerCase()
    ) {
      terms.push(live.scientificName);
    }
    ids = await findLocalSpeciesIds(c.env.DB, terms, limit);
    const localHits: CatalogHit[] = [];
    for (const id of ids) {
      const row = await c.env.DB.prepare("SELECT * FROM species WHERE id = ?")
        .bind(id)
        .first<SpeciesRow>();
      if (!row) continue;
      const groups = readJson<string[]>(row.plant_groups_json, []);
      if (c.req.query("edible") === "true" && !groups.includes("edible")) continue;
      if (c.req.query("vegetable") === "true" && !groups.includes("vegetable")) continue;
      const json = speciesJson(row);
      localHits.push({
        id: json.id,
        scientificName: json.scientificName,
        commonNames: json.commonNames,
        plantGroups: json.plantGroups,
        imageUrl: json.imageUrl,
        trefleSlug: json.trefleSlug,
        family: json.family,
        dataCompleteness: json.dataCompleteness,
      });
    }
    const seen = new Set(live.hits.map((hit) => hit.trefleSlug ?? hit.id));
    const results = [
      ...live.hits,
      ...localHits.filter((hit) => !seen.has(hit.trefleSlug ?? hit.id)),
    ].slice(0, limit);
    return c.json({
      results,
      nextCursor: null,
      attribution: live.attribution,
    });
  }
  const edible = c.req.query("edible") === "true";
  const vegetable = c.req.query("vegetable") === "true";
  // Rank and family are accepted so the app can send one query shape. The
  // local catalog does not store those columns yet, so they are not applied.
  const results = [];
  for (const id of ids) {
    const row = await c.env.DB.prepare("SELECT * FROM species WHERE id = ?").bind(id).first<SpeciesRow>();
    if (!row) continue;
    const groups = readJson<string[]>(row.plant_groups_json, []);
    if (edible && !groups.includes("edible")) continue;
    if (vegetable && !groups.includes("vegetable")) continue;
    results.push(speciesJson(row));
  }
  return c.json({ results, nextCursor: null });
});

speciesRoutes.get("/v1/species/:speciesId/image", async (c) => {
  const row = await c.env.DB.prepare(
    "SELECT image_object_key FROM species WHERE id = ?",
  )
    .bind(c.req.param("speciesId"))
    .first<{ image_object_key: string | null }>();
  if (!row?.image_object_key) {
    throw new ApiError(404, "not_found", "Species image not found.");
  }
  const object = await c.env.IMAGES.get(row.image_object_key);
  if (!object) throw new ApiError(404, "not_found", "Species image not found.");
  return new Response(object.body, {
    headers: {
      "content-type": object.httpMetadata?.contentType ?? "image/jpeg",
      "cache-control": "private, max-age=86400",
    },
  });
});

speciesRoutes.get("/v1/species/:speciesId", async (c) => {
  const row = await c.env.DB.prepare("SELECT * FROM species WHERE id = ?")
    .bind(c.req.param("speciesId"))
    .first<SpeciesRow>();
  if (!row) throw new ApiError(404, "not_found", "Species not found.");
  const profiles = await c.env.DB.prepare(
    "SELECT id, name, tasks_json FROM care_profiles WHERE species_id = ?",
  )
    .bind(row.id)
    .all<{ id: string; name: string; tasks_json: string }>();
  const careProfiles = (profiles.results ?? []).map((profile) => ({
    id: profile.id,
    name: profile.name,
    tasks: readJson(profile.tasks_json, []),
  }));
  return c.json(speciesJson(row, careProfiles));
});

speciesRoutes.post("/v1/species/resolve", async (c) => {
  const body = parseBody(
    z
      .object({
        speciesId: z.string().min(1).max(128).optional(),
        trefleSlug: z.string().min(1).max(128).optional(),
      })
      .strict(),
    await readObject(c),
  );
  if (!body.speciesId && !body.trefleSlug) {
    throw new ApiError(400, "validation_error", "Provide a species id or slug.");
  }
  const cached = await loadCachedSpecies(c.env.DB, body.speciesId, body.trefleSlug);
  const slug = body.trefleSlug ?? cached?.source_id ?? body.speciesId;
  const stale =
    cached !== null && cached.source === "trefle" && !isFresh(cached.updated_at);
  if (!cached || (stale && c.env.TREFLE_API_TOKEN)) {
    if (!slug) {
      throw new ApiError(404, "not_found", "Species is not in the catalog yet.");
    }
    const token = requireTrefleToken(c.env.TREFLE_API_TOKEN);
    await fetchAndStoreSpecies(c.env.DB, slug, token);
  }
  const stored = await loadCachedSpecies(c.env.DB, body.speciesId, body.trefleSlug);
  if (!stored) {
    throw new ApiError(404, "not_found", "Species is not in the catalog yet.");
  }
  const row = await c.env.DB.prepare("SELECT * FROM species WHERE id = ?")
    .bind(stored.id)
    .first<SpeciesRow>();
  if (!row) throw new ApiError(404, "not_found", "Species is not in the catalog yet.");
  const profiles = await c.env.DB.prepare(
    "SELECT id, name, tasks_json FROM care_profiles WHERE species_id = ?",
  )
    .bind(row.id)
    .all<{ id: string; name: string; tasks_json: string }>();
  const careProfiles = (profiles.results ?? []).map((profile) => ({
    id: profile.id,
    name: profile.name,
    tasks: readJson(profile.tasks_json, []),
  }));
  return c.json(speciesJson(row, careProfiles));
});
