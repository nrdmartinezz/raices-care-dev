export interface Env {
  DB: D1Database;
  IMAGES: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  ENVIRONMENT: string;
  DRY_RUN_PUSH: string;
  APP_CHECK_ENFORCE?: string;
  ALLOWED_ORIGINS?: string;
  FCM_SERVICE_ACCOUNT_JSON?: string;
}

export type AppVariables = {
  userId: string;
  authSubject: string;
};

export type AppEnv = {
  Bindings: Env;
  Variables: AppVariables;
};

export const MAX_PHOTO_BYTES = 10 * 1024 * 1024;
export const WRITE_LIMIT_PER_MINUTE = 60;

export function isProduction(env: Env): boolean {
  return env.ENVIRONMENT === "production";
}

export function pushIsDryRun(env: Env): boolean {
  if (!env.FCM_SERVICE_ACCOUNT_JSON) return true;
  return env.DRY_RUN_PUSH !== "false";
}
