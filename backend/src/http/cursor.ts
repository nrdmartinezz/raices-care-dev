import { ApiError } from "./errors";

export function encodeCursor(updatedAt: number, id: string): string {
  return btoa(JSON.stringify({ u: updatedAt, i: id }));
}

export function decodeCursor(raw: string | undefined): {
  updatedAt: number;
  id: string;
} | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(atob(raw)) as { u?: unknown; i?: unknown };
    if (typeof parsed.u !== "number" || typeof parsed.i !== "string") {
      throw new Error("cursor");
    }
    return { updatedAt: parsed.u, id: parsed.i };
  } catch {
    throw new ApiError(400, "validation_error", "Cursor is not valid.");
  }
}

export function pageLimit(raw: string | undefined, fallback = 50): number {
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > 100) {
    throw new ApiError(400, "validation_error", "Limit must be from 1 to 100.");
  }
  return value;
}
