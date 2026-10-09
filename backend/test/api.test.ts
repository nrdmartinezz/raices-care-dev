import { env } from "cloudflare:test";
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type CryptoKey } from "jose";
import { beforeAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app";
import type { Env } from "../src/env";
import { runReminderCron } from "../src/services/push";

const DAY = 24 * 60 * 60 * 1000;
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0x00, 0xd9]);

let app: ReturnType<typeof createApp>;
let privateKey: CryptoKey;

beforeAll(async () => {
  const pair = await generateKeyPair("RS256", { extractable: true });
  privateKey = pair.privateKey;
  const jwk = await exportJWK(pair.publicKey);
  jwk.alg = "RS256";
  jwk.kid = "test";
  app = createApp({ jwks: createLocalJWKSet({ keys: [jwk] }) });
});

async function signToken(options?: {
  sub?: string;
  audience?: string;
  issuer?: string;
  expiresIn?: string | number;
}) {
  return new SignJWT({})
    .setProtectedHeader({ alg: "RS256", kid: "test" })
    .setSubject(options?.sub ?? "user-a")
    .setAudience(options?.audience ?? "raices-care")
    .setIssuer(options?.issuer ?? "https://securetoken.google.com/raices-care")
    .setIssuedAt()
    .setExpirationTime(options?.expiresIn ?? "1h")
    .sign(privateKey);
}

function call(path: string, init: RequestInit = {}, bindings: Env = env) {
  return app.request(path, init, bindings);
}

function dev(userId: string, init: RequestInit = {}): RequestInit {
  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer dev:${userId}`);
  return { ...init, headers };
}

describe("auth", () => {
  it("serves health without a token", async () => {
    const response = await call("/health");
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ ok: true });
  });

  it("rejects a missing token", async () => {
    const response = await call("/v1/me");
    expect(response.status).toBe(401);
  });

  it("accepts a valid Firebase token", async () => {
    const token = await signToken();
    const response = await call("/v1/me", {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ id: "user-a" });
  });

  it("rejects an expired token", async () => {
    const token = await signToken({ expiresIn: Math.floor(Date.now() / 1000) - 60 });
    const response = await call("/v1/me", {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(response.status).toBe(401);
  });

  it("rejects the wrong audience and issuer", async () => {
    const audience = await signToken({ audience: "other-project" });
    const issuer = await signToken({ issuer: "https://securetoken.google.com/other-project" });
    expect((await call("/v1/me", { headers: { Authorization: `Bearer ${audience}` } })).status).toBe(401);
    expect((await call("/v1/me", { headers: { Authorization: `Bearer ${issuer}` } })).status).toBe(401);
  });

  it("rejects an unsigned token", async () => {
    const header = btoa(JSON.stringify({ alg: "none", typ: "JWT" })).replace(/=+$/g, "");
    const payload = btoa(
      JSON.stringify({
        sub: "user-a",
        aud: "raices-care",
        iss: "https://securetoken.google.com/raices-care",
        exp: Math.floor(Date.now() / 1000) + 3600,
      }),
    ).replace(/=+$/g, "");
    const response = await call("/v1/me", {
      headers: { Authorization: `Bearer ${header}.${payload}.` },
    });
    expect(response.status).toBe(401);
  });

  it("allows the development bypass only in development", async () => {
    expect((await call("/v1/me", dev("dev-user"))).status).toBe(200);
    const production = { ...env, ENVIRONMENT: "production" } as Env;
    expect((await call("/v1/me", dev("dev-user"), production)).status).toBe(401);
  });
});

describe("records stay on their owner", () => {
  it("hides another user's plant", async () => {
    const created = await call(
      "/v1/gardens",
      dev("owner", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ id: "garden-owner", name: "Window" }),
      }),
    );
    expect(created.status).toBe(201);
    const plant = await call(
      "/v1/plants",
      dev("owner", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ id: "plant-owner", gardenId: "garden-owner", nickname: "Fern" }),
      }),
    );
    expect(plant.status).toBe(201);

    const hidden = await call("/v1/plants/plant-owner", dev("other"));
    expect(hidden.status).toBe(404);
    const list = await call("/v1/plants", dev("other"));
    const body = (await list.json()) as { results: unknown[] };
    expect(body.results).toEqual([]);
  });

  it("deletes the garden with the account", async () => {
    expect(
      (
        await call(
          "/v1/gardens",
          dev("closing", {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({ id: "garden-closing", name: "Sill" }),
          }),
        )
      ).status,
    ).toBe(201);
    expect(
      (
        await call(
          "/v1/plants",
          dev("closing", {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({
              id: "plant-closing",
              gardenId: "garden-closing",
              nickname: "Fern",
            }),
          }),
        )
      ).status,
    ).toBe(201);
    await env.DB.prepare(
      `INSERT INTO reminders (id, user_id, plant_id, task_type, title, due_at, status, created_at, updated_at)
       VALUES ('rem-closing', 'closing', 'plant-closing', 'water_check', 'Check water', ?, 'open', ?, ?)`,
    )
      .bind(Date.now(), Date.now(), Date.now())
      .run();
    await env.DB.prepare(
      "INSERT INTO idempotency_keys (user_id, key, request_hash, status, response_json, created_at) VALUES ('closing', 'once', 'hash', 201, '{}', ?)",
    )
      .bind(Date.now())
      .run();

    const deleted = await call("/v1/me", dev("closing", { method: "DELETE" }));
    expect(deleted.status).toBe(204);
    expect((await call("/v1/me", dev("closing"))).status).toBe(404);
    expect((await call("/v1/plants/plant-closing", dev("closing"))).status).toBe(404);
    const reminders = await env.DB.prepare(
      "SELECT id FROM reminders WHERE user_id = 'closing' AND deleted_at IS NULL",
    ).all();
    expect(reminders.results).toEqual([]);
    const keys = await env.DB.prepare(
      "SELECT key FROM idempotency_keys WHERE user_id = 'closing'",
    ).all();
    expect(keys.results).toEqual([]);
  });

  it("replays a create with the same idempotency key", async () => {
    const init = dev("idem-user", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "Idempotency-Key": "garden-once",
      },
      body: JSON.stringify({ id: "garden-once", name: "Porch" }),
    });
    const first = await call("/v1/gardens", init);
    const second = await call("/v1/gardens", init);
    expect(first.status).toBe(201);
    expect(second.status).toBe(201);
    expect(await second.json()).toEqual(await first.json());
  });
});

describe("reminders", () => {
  it("seeds a reminder and rolls it forward after care", async () => {
    const ts = Date.now();
    await env.DB.prepare(
      `INSERT INTO species (id, scientific_name, common_names_json, plant_groups_json, toxicity_json, created_at, updated_at)
       VALUES ('basil', 'Ocimum basilicum', '["basil"]', '["herb"]', '{}', ?, ?)`,
    )
      .bind(ts, ts)
      .run();
    await env.DB.prepare(
      `INSERT INTO care_profiles (id, species_id, name, tasks_json, created_at, updated_at)
       VALUES ('basil-default', 'basil', 'Default', ?, ?, ?)`,
    )
      .bind(
        JSON.stringify([
          { taskType: "water_check", title: "Check water", intervalDays: 7, priority: "normal" },
        ]),
        ts,
        ts,
      )
      .run();

    expect(
      (
        await call(
          "/v1/gardens",
          dev("grower", {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({ id: "garden-grower", name: "Kitchen" }),
          }),
        )
      ).status,
    ).toBe(201);
    expect(
      (
        await call(
          "/v1/plants",
          dev("grower", {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({
              id: "plant-basil",
              gardenId: "garden-grower",
              speciesId: "basil",
            }),
          }),
        )
      ).status,
    ).toBe(201);

    const before = await call("/v1/reminders?plantId=plant-basil", dev("grower"));
    const beforeBody = (await before.json()) as { results: { id: string; dueAt: string }[] };
    expect(beforeBody.results.map((item) => item.id)).toContain("plant-basil__water_check");
    const previousDue = Date.parse(beforeBody.results[0].dueAt);

    const occurredAt = new Date(ts + 3 * DAY).toISOString();
    const logged = await call(
      "/v1/plants/plant-basil/care-events",
      dev("grower", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ eventType: "watered", occurredAt }),
      }),
    );
    expect(logged.status).toBe(201);

    const after = await call("/v1/reminders?plantId=plant-basil", dev("grower"));
    const afterBody = (await after.json()) as { results: { dueAt: string }[] };
    expect(Date.parse(afterBody.results[0].dueAt)).toBeGreaterThan(previousDue);
  });

  it("records a dry-run delivery and does not mark it sent", async () => {
    const dueAt = Date.now() - 1000;
    const ts = Date.now();
    await env.DB.prepare(
      "INSERT INTO users (id, created_at, updated_at) VALUES ('notifier', ?, ?) ON CONFLICT(id) DO NOTHING",
    )
      .bind(ts, ts)
      .run();
    await env.DB.prepare(
      `INSERT INTO reminders (
        id, user_id, plant_id, task_type, title, due_at, status, priority,
        schedule_source, created_at, updated_at
      ) VALUES ('rem-due', 'notifier', 'plant-x', 'custom', 'Water', ?, 'open', 'normal', 'user', ?, ?)`,
    )
      .bind(dueAt, ts, ts)
      .run();
    await env.DB.prepare(
      "INSERT INTO device_tokens (token, user_id, platform, created_at, updated_at) VALUES ('token-1', 'notifier', 'ios', ?, ?)",
    )
      .bind(ts, ts)
      .run();

    const result = await runReminderCron(env);
    expect(result.dryRun).toBe(true);
    const delivery = await env.DB.prepare(
      "SELECT status FROM notification_deliveries WHERE reminder_id = 'rem-due'",
    ).first<{ status: string }>();
    expect(delivery?.status).toBe("dry_run");
  });
});

describe("photos", () => {
  it("stores a private image and refuses another user", async () => {
    await call(
      "/v1/gardens",
      dev("photo-user", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ id: "garden-photo", name: "Shelf" }),
      }),
    );
    await call(
      "/v1/plants",
      dev("photo-user", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ id: "plant-photo", gardenId: "garden-photo" }),
      }),
    );

    const uploaded = await call(
      "/v1/plants/plant-photo/photos",
      dev("photo-user", {
        method: "POST",
        headers: { "content-type": "image/jpeg" },
        body: jpeg,
      }),
    );
    expect(uploaded.status).toBe(201);
    const created = (await uploaded.json()) as { id: string };
    const streamed = await call(`/v1/photos/${created.id}`, dev("photo-user"));
    expect(streamed.status).toBe(200);
    expect(streamed.headers.get("cache-control")).toBe("private, max-age=300");
    expect(new Uint8Array(await streamed.arrayBuffer())).toEqual(jpeg);

    expect((await call(`/v1/photos/${created.id}`, dev("photo-other"))).status).toBe(404);

    const garbage = await call(
      "/v1/plants/plant-photo/photos",
      dev("photo-user", {
        method: "POST",
        headers: { "content-type": "image/jpeg" },
        body: new Uint8Array([1, 2, 3, 4]),
      }),
    );
    expect(garbage.status).toBe(415);

    const huge = await call(
      "/v1/plants/plant-photo/photos",
      dev("photo-user", {
        method: "POST",
        headers: { "content-type": "image/jpeg", "content-length": "11000000" },
        body: jpeg,
      }),
    );
    expect(huge.status).toBe(413);

    expect((await call(`/v1/photos/${created.id}`, dev("photo-user", { method: "DELETE" }))).status).toBe(204);
    expect((await call(`/v1/photos/${created.id}`, dev("photo-user"))).status).toBe(404);
  });
});

describe("species search", () => {
  it("returns the catalog image with each result", async () => {
    const ts = Date.now();
    await env.IMAGES.put("species/rosemary/cover.jpg", jpeg, {
      httpMetadata: { contentType: "image/jpeg" },
    });
    await env.DB.prepare(
      `INSERT INTO species (
        id, scientific_name, common_names_json, plant_groups_json, toxicity_json,
        image_object_key, created_at, updated_at
      ) VALUES ('rosemary', 'Salvia rosmarinus', '["rosemary"]', '["herb"]', '{}', ?, ?, ?)`,
    )
      .bind("species/rosemary/cover.jpg", ts, ts)
      .run();

    const listed = await call("/v1/species?q=rosemary", dev("searcher"));
    expect(listed.status).toBe(200);
    const body = (await listed.json()) as { results: { id: string; imageUrl: string | null }[] };
    expect(body.results.map((item) => item.id)).toContain("rosemary");
    expect(body.results.find((item) => item.id === "rosemary")?.imageUrl).toBe(
      "/v1/species/rosemary/image",
    );

    const image = await call("/v1/species/rosemary/image", dev("searcher"));
    expect(image.status).toBe(200);
    expect(image.headers.get("content-type")).toBe("image/jpeg");
    expect(new Uint8Array(await image.arrayBuffer())).toEqual(jpeg);
    expect((await call("/v1/species/missing/image", dev("searcher"))).status).toBe(404);
  });

  it("keeps only species whose plant groups match edible and vegetable", async () => {
    const ts = Date.now();
    await env.DB.prepare(
      `INSERT INTO species (
        id, scientific_name, common_names_json, plant_groups_json, toxicity_json,
        created_at, updated_at
      ) VALUES
        ('tomato', 'Solanum lycopersicum', '["tomato"]', '["vegetable"]', '{}', ?, ?),
        ('basil-herb', 'Ocimum basilicum', '["basil"]', '["herb"]', '{}', ?, ?)`,
    )
      .bind(ts, ts, ts, ts)
      .run();

    const vegetable = await call(
      "/v1/species?q=tomato&vegetable=true&rank=species&family=Solanaceae",
      dev("searcher"),
    );
    expect(vegetable.status).toBe(200);
    const vegetableBody = (await vegetable.json()) as { results: { id: string }[] };
    expect(vegetableBody.results.map((item) => item.id)).toEqual(["tomato"]);

    const edible = await call("/v1/species?q=tomato&edible=true", dev("searcher"));
    const edibleBody = (await edible.json()) as { results: { id: string }[] };
    expect(edibleBody.results).toEqual([]);
  });
});
