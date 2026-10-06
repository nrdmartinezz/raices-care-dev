import type { Context } from "hono";
import type { AppEnv } from "../env";

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly details: Record<string, unknown> = {},
  ) {
    super(message);
  }
}

export function errorBody(error: ApiError) {
  return {
    error: {
      code: error.code,
      message: error.message,
      details: error.details,
    },
  };
}

export function onError(err: Error, c: Context<AppEnv>) {
  if (err instanceof ApiError) {
    return c.json(errorBody(err), err.status as 400);
  }
  console.error(
    JSON.stringify({
      message: "unhandled",
      path: new URL(c.req.url).pathname,
      error: err.message,
    }),
  );
  return c.json(
    {
      error: {
        code: "internal",
        message: "Something went wrong.",
        details: {},
      },
    },
    500,
  );
}
