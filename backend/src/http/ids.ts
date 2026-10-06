import { ApiError } from "./errors";

const ID = /^[A-Za-z0-9_-]{1,128}$/;

export function clientId(value: unknown, label = "id"): string {
  if (typeof value !== "string" || !ID.test(value)) {
    throw new ApiError(400, "validation_error", `${label} is not a valid id.`);
  }
  return value;
}

export function optionalClientId(value: unknown, label = "id"): string {
  if (value === undefined || value === null || value === "") {
    return crypto.randomUUID();
  }
  return clientId(value, label);
}

export function now(): number {
  return Date.now();
}

export function iso(ms: number | null | undefined): string | null {
  if (ms === null || ms === undefined) return null;
  return new Date(ms).toISOString();
}

export function parseTime(value: unknown, label: string): number {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    if (!Number.isNaN(parsed)) return parsed;
  }
  throw new ApiError(400, "validation_error", `${label} must be a timestamp.`);
}

export function optionalTime(value: unknown, label: string): number | null {
  if (value === undefined || value === null) return null;
  return parseTime(value, label);
}

export async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function jsonText(value: unknown): string {
  return JSON.stringify(value ?? null);
}

export function readJson<T>(raw: string | null | undefined, fallback: T): T {
  if (!raw) return fallback;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}
