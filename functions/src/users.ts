import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

import { db, FieldValue } from "./admin";
import { DEFAULT_REGION, SCHEMA_VERSION } from "./schema";

/**
 * Fills in safe defaults when a user document first appears.
 *
 * Only keys the client left absent are written, so anything chosen during
 * onboarding survives both this trigger and any retry of it.
 *
 * An Auth-trigger alternative: swap this for a blocking
 * `beforeUserCreated` function, or a `functions.auth.user().onCreate`
 * (v1) handler, and create /users/{uid} there instead. Keeping the trigger on
 * the Firestore document means the client controls when the profile exists,
 * which keeps anonymous and multi-step sign-up flows simpler.
 */
export const onUserCreated = onDocumentCreated(
  { document: "users/{uid}", region: DEFAULT_REGION },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const uid = event.params.uid;
    const current = snapshot.data() ?? {};
    const defaults: Record<string, unknown> = {};

    if (current.units === undefined) {
      defaults.units = {
        temperature: "F",
        distance: "imperial",
        volume: "us_customary",
      };
    }

    if (current.notificationPreferences === undefined) {
      defaults.notificationPreferences = {
        pushEnabled: true,
        emailEnabled: false,
        quietHours: { start: "21:00", end: "08:00" },
      };
    }

    if (current.homeLocation === undefined) {
      defaults.homeLocation = {
        countryCode: null,
        state: null,
        city: null,
        postalCode: null,
        hardinessZone: null,
        timezone: null,
      };
    }

    if (current.schemaVersion === undefined) {
      defaults.schemaVersion = SCHEMA_VERSION;
    }

    if (current.createdAt === undefined) {
      defaults.createdAt = FieldValue.serverTimestamp();
    }

    if (Object.keys(defaults).length > 0) {
      defaults.updatedAt = FieldValue.serverTimestamp();
      await snapshot.ref.set(defaults, { merge: true });
    }

    // Private settings live in their own document so push tokens and other
    // sensitive values never ride along with the readable profile.
    await db.doc(`users/${uid}/settings/private`).set(
      {
        fcmTokens: current.fcmTokens ?? [],
        lastSeenAt: FieldValue.serverTimestamp(),
        schemaVersion: SCHEMA_VERSION,
      },
      { merge: true },
    );

    logger.info("Initialized user", { uid, filled: Object.keys(defaults) });
  },
);
