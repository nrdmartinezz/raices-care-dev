import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";

import { db, FieldValue } from "./admin";
import {
  CareProfileDoc,
  CareProfileTask,
  DEFAULT_REGION,
  DERIVED_CARE_PROFILE_ID,
  SCHEMA_VERSION,
  daysFromNow,
} from "./schema";

/**
 * App Check stays advisory until the app has been exercised on real devices.
 * Matches the catalog callables.
 */
const ENFORCE_APP_CHECK = false;

/** Named so a deploy always applies the Cloud Run invoker binding. */
const PUBLIC_INVOKER = "public";

/** Maps a care task onto the plant field that tracks when it is next due. */
const NEXT_ACTION_FIELD: Partial<Record<CareProfileTask["taskType"], string>> = {
  water_check: "nextWaterCheckAt",
  fertilize: "nextFertilizeAt",
  pest_check: "nextPestCheckAt",
};

/**
 * Writes one open reminder per care-profile task.
 *
 * Reminder ids are `{plantId}__{taskType}`. A reminder that already exists is
 * left alone, so adding a plant to chores twice does not duplicate or reset
 * a task the gardener has already moved.
 */
export async function seedCareProfileReminders(input: {
  uid: string;
  plantId: string;
  speciesId: string;
  profileId: string;
  tasks: CareProfileTask[];
}): Promise<number> {
  const remindersRef = db.collection(`users/${input.uid}/reminders`);
  const plantRef = db.doc(`users/${input.uid}/plants/${input.plantId}`);
  const nextActions: Record<string, unknown> = {};
  const batch = db.batch();
  let created = 0;

  for (const task of input.tasks) {
    const reminderId = `${input.plantId}__${task.taskType}`;
    const reminderRef = remindersRef.doc(reminderId);

    // eslint-disable-next-line no-await-in-loop -- a handful of tasks per plant
    const existing = await reminderRef.get();
    if (existing.exists) {
      continue;
    }

    const dueAt = daysFromNow(task.intervalDays);
    batch.set(reminderRef, {
      plantId: input.plantId,
      speciesId: input.speciesId,
      taskType: task.taskType,
      title: task.title,
      instructions: task.instructions,
      dueAt,
      status: "open",
      priority: task.priority,
      schedule: {
        mode: "interval",
        source: "care_profile",
        careProfileId: input.profileId,
        intervalDays: task.intervalDays,
      },
      completedAt: null,
      snoozedUntil: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      schemaVersion: SCHEMA_VERSION,
    });
    created += 1;

    const field = NEXT_ACTION_FIELD[task.taskType];
    if (field) {
      nextActions[`nextActions.${field}`] = dueAt;
    }
  }

  if (created === 0) {
    return 0;
  }

  if (Object.keys(nextActions).length > 0) {
    batch.update(plantRef, {
      ...nextActions,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  return created;
}

/**
 * Records the species on a new plant. Chores stay off until `addPlantToChores`.
 */
export const onPlantCreated = onDocumentCreated(
  { document: "users/{uid}/plants/{plantId}", region: DEFAULT_REGION },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const { uid, plantId } = event.params;
    const plant = snapshot.data() ?? {};
    const speciesId = plant.speciesId as string | undefined;

    if (!speciesId) {
      logger.warn("Plant created without a speciesId", { uid, plantId });
      return;
    }

    const speciesSnapshot = await db.doc(`species/${speciesId}`).get();
    if (!speciesSnapshot.exists) {
      // The catalog is lazily filled, so a client can legitimately reference a
      // species that has not been cached yet. Flag it rather than failing, and
      // let the client call resolveSpecies before adding the plant to chores.
      logger.warn("Plant references an uncached species", {
        uid,
        plantId,
        speciesId,
      });
      await snapshot.ref.set(
        {
          catalogStatus: "species_missing",
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return;
    }

    const species = speciesSnapshot.data() ?? {};
    const plantUpdate: Record<string, unknown> = {
      catalogStatus: "resolved",
      updatedAt: FieldValue.serverTimestamp(),
    };

    // Denormalize the few species fields dashboards read, so listing a garden
    // never needs a second read per plant.
    if (plant.speciesNameSnapshot === undefined) {
      plantUpdate.speciesNameSnapshot =
        species.scientificName ?? species.commonName ?? speciesId;
    }
    if (plant.plantGroupSnapshot === undefined) {
      plantUpdate.plantGroupSnapshot = species.plantGroups ?? [];
    }

    await snapshot.ref.set(plantUpdate, { merge: true });
    logger.info("Recorded plant species", { uid, plantId, speciesId });
  },
);

/**
 * Puts one garden plant on the chores list from its derived care profile.
 *
 * The client calls `resolveSpecies` first when the species or profile is
 * missing. This function does not talk to Trefle; it only materializes the
 * profile that resolve already stored.
 */
export const addPlantToChores = onCall(
  {
    region: DEFAULT_REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    invoker: PUBLIC_INVOKER,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to schedule care.");
    }

    const plantId = String(request.data?.plantId ?? "").trim();
    if (!plantId || plantId.includes("/")) {
      throw new HttpsError("invalid-argument", "Provide a plant id.");
    }

    const uid = request.auth.uid;
    const plantSnapshot = await db.doc(`users/${uid}/plants/${plantId}`).get();
    if (!plantSnapshot.exists) {
      throw new HttpsError("not-found", "That plant is not in your garden.");
    }

    const plant = plantSnapshot.data() ?? {};
    const speciesId = plant.speciesId as string | undefined;
    if (!speciesId) {
      throw new HttpsError(
        "failed-precondition",
        "This plant has no species to build a care rhythm from.",
      );
    }

    const speciesSnapshot = await db.doc(`species/${speciesId}`).get();
    if (!speciesSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Resolve the species before adding it to chores.",
      );
    }

    const profileId =
      (plant.careProfileId as string | undefined) ?? DERIVED_CARE_PROFILE_ID;
    const profileSnapshot = await db
      .doc(`species/${speciesId}/careProfiles/${profileId}`)
      .get();
    if (!profileSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "This species has no care profile yet. Resolve it and try again.",
      );
    }

    const profile = profileSnapshot.data() as CareProfileDoc;
    const created = await seedCareProfileReminders({
      uid,
      plantId,
      speciesId,
      profileId,
      tasks: profile.tasks ?? [],
    });

    logger.info("Added plant to chores", { uid, plantId, speciesId, created });
    return { created, careProfileId: profileId };
  },
);

/**
 * Removes what Firestore leaves behind when a plant document is deleted.
 *
 * The client deletes only the plant. Care events, notes, photo documents,
 * reminders, and Storage files are cleaned up here so one dropped connection
 * cannot stop halfway through them.
 */
export const onPlantDeleted = onDocumentDeleted(
  { document: "users/{uid}/plants/{plantId}", region: DEFAULT_REGION },
  async (event) => {
    const { uid, plantId } = event.params;
    const plantRef = db.doc(`users/${uid}/plants/${plantId}`);

    const collections = await plantRef.listCollections();
    for (const collection of collections) {
      await db.recursiveDelete(collection);
    }

    const reminders = await db
      .collection(`users/${uid}/reminders`)
      .where("plantId", "==", plantId)
      .get();

    const chunk = 400;
    for (let index = 0; index < reminders.size; index += chunk) {
      const batch = db.batch();
      for (const doc of reminders.docs.slice(index, index + chunk)) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }

    try {
      await getStorage()
        .bucket()
        .deleteFiles({ prefix: `users/${uid}/plants/${plantId}/` });
    } catch (error) {
      logger.warn("Plant photo cleanup failed", { uid, plantId, error });
    }

    logger.info("Removed plant leftovers", {
      uid,
      plantId,
      reminders: reminders.size,
    });
  },
);
