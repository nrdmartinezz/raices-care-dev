import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "jose";
import type { Env } from "../env";
import { ApiError } from "../http/errors";

const GOOGLE_JWKS =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

let remoteKeys: JWTVerifyGetKey | undefined;

function googleKeys(): JWTVerifyGetKey {
  remoteKeys ??= createRemoteJWKSet(new URL(GOOGLE_JWKS));
  return remoteKeys;
}

export type VerifiedUser = {
  userId: string;
  subject: string;
};

/**
 * Verifies a Firebase ID token. `keys` is injected in tests so they do not
 * call Google. Production uses the Secure Token service JWKS.
 */
export async function verifyFirebaseToken(
  token: string,
  env: Env,
  keys?: JWTVerifyGetKey,
): Promise<VerifiedUser> {
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw new ApiError(500, "internal", "Auth is not configured.");
  }
  try {
    const { payload, protectedHeader } = await jwtVerify(token, keys ?? googleKeys(), {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
      algorithms: ["RS256"],
    });
    if (protectedHeader.alg !== "RS256") {
      throw new ApiError(401, "unauthenticated", "Sign in is required.");
    }
    const subject = payload.sub;
    if (!subject) {
      throw new ApiError(401, "unauthenticated", "Sign in is required.");
    }
    return { userId: subject, subject };
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(401, "unauthenticated", "Sign in is required.");
  }
}

/**
 * Development-only stand-in. A token of the form `dev:<userId>` is accepted
 * only when ENVIRONMENT is exactly "development".
 */
export function developmentUser(token: string, env: Env): VerifiedUser | null {
  if (env.ENVIRONMENT !== "development") return null;
  if (!token.startsWith("dev:")) return null;
  const userId = token.slice(4);
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(userId)) return null;
  return { userId, subject: userId };
}
