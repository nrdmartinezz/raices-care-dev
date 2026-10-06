import type { Context } from "hono";
import type { ZodType } from "zod";
import type { AppEnv } from "../env";
import { ApiError } from "./errors";

export async function readObject(c: Context<AppEnv>): Promise<Record<string, unknown>> {
  const text = await c.req.text();
  if (!text.trim()) return {};
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new ApiError(400, "validation_error", "Body must be JSON.");
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new ApiError(400, "validation_error", "Body must be a JSON object.");
  }
  const body = { ...(parsed as Record<string, unknown>) };
  delete body.userId;
  delete body.user_id;
  return body;
}

export function parseBody<T>(schema: ZodType<T>, body: Record<string, unknown>): T {
  const result = schema.safeParse(body);
  if (!result.success) {
    throw new ApiError(400, "validation_error", "Request is not valid.", {
      issues: result.error.issues.map((issue) => ({
        path: issue.path.join("."),
        message: issue.message,
      })),
    });
  }
  return result.data;
}
