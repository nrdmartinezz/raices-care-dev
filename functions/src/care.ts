import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { Timestamp } from "firebase-admin/firestore";

import { db, FieldValue } from "./admin";
import {
  CareEventType,
  DEFAULT_REGION,
  ReminderTaskType,
  SCHEMA_VERSION,
} from "./schema";

interface CareEffect {
  /** Dotted path on the plant document that records when this last happened. */
  lastDoneField: string;
  /** Dotted path that records when it is next due, when the task repeats. */
  nextDueField?: string;
  /** Reminder task type this event satisfies. */
  satisfies?: ReminderTaskType;
  /** Fallback cadence when the reminder carries no interval of its own. */
  fallbackIntervalDays?: number;
}

/**
 * The deliberately simple, explainable mapping from a logged event to the
 * plant fields it refreshes. Weather- and season-aware scheduling is not
 * attempted here; these are placeholders with fixed cadences.
 */
const CARE_EFFECTS: Partial<Record<CareEventType, CareEffect>> = {
  watered: {
    lastDoneField: "currentCare.lastWateredAt",
    nextDueField: "nextActions.nextWaterCheckAt",
    satisfies: "water_check",
    fallbackIntervalDays: 7,
  },
  fertilized: {
    lastDoneField: "currentCare.lastFertilizedAt",
    nextDueField: "nextActions.nextFertilizeAt",
    satisfies: "fertilize",
    fallbackIntervalDays: 30,
  },
  pruned: {
    lastDoneField: "currentCare.lastPrunedAt",
    satisfies: "prune",
  },
  repotted: {
    lastDoneField: "currentCare.lastRepottedAt",
    satisfies: "repot",
  },
  pest_inspection: {
    lastDoneField: "currentCare.lastPestInspectionAt",
    nextDueField: "nextActions.nextPestCheckAt",
    satisfies: "pest_check",
    fallbackIntervalDays: 14,
  },
  health_check: {
    lastDoneField: "status.lastHealthCheckAt",
  },
};

function readDottedField(
  data: Record<string, unknown>,
  path: string,
): unknown {
  return path
    .split(".")
    .reduce<unknown>(
      (value, key) =>
        value && typeof value === "object"
          ? (value as Record<string, unknown>)[key]
          : undefined,
      data,
    );
}

/**
 * Recalculates a plant's care state after an event is logged.
 *
 * Idempotency comes from only ever moving timestamps forward: replaying the
 * same event, or processing two events out of order, converges on the same
 * result. Nothing here writes a careEvent, so the trigger cannot re-enter.
 */
export const onCareEventCreated = onDocumentCreated(
  {
    document: "users/{uid}/plants/{plantId}/careEvents/{eventId}",
    region: DEFAULT_REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const { uid, plantId } = event.params;
    const careEvent = snapshot.data() ?? {};
    const eventType = careEvent.eventType as CareEventType | undefined;
    const occurredAt = careEvent.occurredAt as Timestamp | undefined;

    if (!eventType || !occurredAt) {
      logger.warn("Care event missing eventType or occurredAt", {
        uid,
        plantId,
      });
      return;
    }

    const effect = CARE_EFFECTS[eventType];
    if (!effect) {
      // Informational events such as `harvested` or `photo_added` need no
      // recalculation today.
      return;
    }

    const plantRef = db.doc(`users/${uid}/plants/${plantId}`);
    const plantSnapshot = await plantRef.get();
    if (!plantSnapshot.exists) {
      return;
    }

    const plant = plantSnapshot.data() ?? {};
    const previous = readDottedField(plant, effect.lastDoneField);
    if (previous instanceof Timestamp && previous.toMillis() >= occurredAt.toMillis()) {
      // A newer event already advanced this field.
      return;
    }

    const plantUpdate: Record<string, unknown> = {
      [effect.lastDoneField]: occurredAt,
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (effect.satisfies) {
      const canonicalRef = db.doc(
        `users/${uid}/reminders/${plantId}__${effect.satisfies}`,
      );
      const canonical = await canonicalRef.get();
      const intervalDays =
        (canonical.data()?.schedule?.intervalDays as number | undefined) ??
        effect.fallbackIntervalDays;

      if (intervalDays) {
        const nextDueAt = Timestamp.fromMillis(
          occurredAt.toMillis() + intervalDays * 24 * 60 * 60 * 1000,
        );

        if (effect.nextDueField) {
          plantUpdate[effect.nextDueField] = nextDueAt;
        }

        // Roll the recurring reminder forward rather than completing it, so a
        // plant always has exactly one live reminder per task type.
        if (canonical.exists) {
          await canonicalRef.set(
            {
              dueAt: nextDueAt,
              status: "open",
              completedAt: occurredAt,
              snoozedUntil: null,
              updatedAt: FieldValue.serverTimestamp(),
              schemaVersion: SCHEMA_VERSION,
            },
            { merge: true },
          );
        }
      }

      // Any other open reminder for the same task is now stale, including ones
      // the user added by hand before logging this event.
      const stale = await db
        .collection(`users/${uid}/reminders`)
        .where("plantId", "==", plantId)
        .where("taskType", "==", effect.satisfies)
        .where("status", "==", "open")
        .get();

      const batch = db.batch();
      let closed = 0;
      for (const doc of stale.docs) {
        if (doc.id === `${plantId}__${effect.satisfies}`) {
          continue;
        }
        batch.set(
          doc.ref,
          {
            status: "completed",
            completedAt: occurredAt,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        closed += 1;
      }
      if (closed > 0) {
        await batch.commit();
      }
    }

    await plantRef.set(plantUpdate, { merge: true });
    logger.info("Recalculated plant care", { uid, plantId, eventType });
  },
);
