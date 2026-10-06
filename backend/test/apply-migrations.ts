import { applyD1Migrations, env } from "cloudflare:test";

type Migration = { name: string; queries: string[] };

const bindings = env as unknown as { DB: D1Database; TEST_MIGRATIONS: Migration[] | string };
const migrations =
  typeof bindings.TEST_MIGRATIONS === "string"
    ? (JSON.parse(bindings.TEST_MIGRATIONS) as Migration[])
    : bindings.TEST_MIGRATIONS;

await applyD1Migrations(bindings.DB, migrations);
