import { Hono } from "hono";
import { z } from "zod";
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
    hasImage: !!row.image_object_key,
    imageUrl: row.image_object_key ? `/v1/species/${row.id}/image` : null,
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
    const match = query
      .replace(/["*]/g, " ")
      .split(/\s+/)
      .filter(Boolean)
      .map((term) => `"${term}"*`)
      .join(" ");
    try {
      const found = await c.env.DB.prepare(
        "SELECT species_id FROM species_fts WHERE species_fts MATCH ? LIMIT ?",
      )
        .bind(match, limit)
        .all<{ species_id: string }>();
      ids = (found.results ?? []).map((row) => row.species_id);
    } catch {
      ids = [];
    }
    if (ids.length === 0) {
      const like = `%${query.replace(/[%_]/g, "")}%`;
      const found = await c.env.DB.prepare(
        `SELECT id FROM species
         WHERE scientific_name LIKE ? OR common_names_json LIKE ?
         ORDER BY scientific_name LIMIT ?`,
      )
        .bind(like, like, limit)
        .all<{ id: string }>();
      ids = (found.results ?? []).map((row) => row.id);
    }
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
  const row = body.speciesId
    ? await c.env.DB.prepare("SELECT * FROM species WHERE id = ?").bind(body.speciesId).first<SpeciesRow>()
    : await c.env.DB.prepare("SELECT * FROM species WHERE source_id = ? OR id = ?")
        .bind(body.trefleSlug, body.trefleSlug)
        .first<SpeciesRow>();
  if (!row) throw new ApiError(404, "not_found", "Species is not in the catalog yet.");
  return c.json(speciesJson(row));
});
