import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
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

/** Maps a care task onto the plant field that tracks when it is next due. */
const NEXT_ACTION_FIELD: Partial<Record<CareProfileTask["taskType"], string>> = {
  water_check: "nextWaterCheckAt",
  fertilize: "nextFertilizeAt",
  pest_check: "nextPestCheckAt",
};

/**
 * Seeds a new plant with reminders drawn from its species care profile.
 *
 * Reminder ids are derived from the plant and task type, so a retry of this
 * trigger rewrites the same documents instead of creating duplicates. Existing
 * reminders are left alone entirely, in case the user has already acted on one.
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
      // let the client call resolveSpecies to populate it.
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
    const profileId =
      (plant.careProfileId as string | undefined) ?? DERIVED_CARE_PROFILE_ID;
    const profileSnapshot = await db
      .doc(`species/${speciesId}/careProfiles/${profileId}`)
      .get();

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

    if (!profileSnapshot.exists) {
      logger.warn("Species has no care profile; seeding no reminders", {
        speciesId,
        profileId,
      });
      await snapshot.ref.set(plantUpdate, { merge: true });
      return;
    }

    const profile = profileSnapshot.data() as CareProfileDoc;
    const tasks = profile.tasks ?? [];

    const remindersRef = db.collection(`users/${uid}/reminders`);
    const nextActions: Record<string, unknown> = {};
    const batch = db.batch();
    let created = 0;

    for (const task of tasks) {
      const reminderId = `${plantId}__${task.taskType}`;
      const reminderRef = remindersRef.doc(reminderId);

      // eslint-disable-next-line no-await-in-loop -- a handful of tasks per plant
      const existing = await reminderRef.get();
      if (existing.exists) {
        continue;
      }

      const dueAt = daysFromNow(task.intervalDays);
      batch.set(reminderRef, {
        plantId,
        speciesId,
        taskType: task.taskType,
        title: task.title,
        instructions: task.instructions,
        dueAt,
        status: "open",
        priority: task.priority,
        schedule: {
          mode: "interval",
          source: "care_profile",
          careProfileId: profileId,
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

    batch.set(snapshot.ref, plantUpdate, { merge: true });
    if (Object.keys(nextActions).length > 0) {
      batch.update(snapshot.ref, nextActions);
    }

    await batch.commit();
    logger.info("Seeded plant reminders", { uid, plantId, speciesId, created });
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
