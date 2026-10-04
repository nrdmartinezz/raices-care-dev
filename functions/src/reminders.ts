import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { getMessaging } from "firebase-admin/messaging";
import { Timestamp } from "firebase-admin/firestore";

import { db, FieldValue, isEmulated } from "./admin";
import { DEFAULT_REGION } from "./schema";

/**
 * Push delivery stays off until a device-token strategy is agreed: where
 * tokens are written, how they are refreshed on reinstall, and how stale ones
 * are pruned. Until then this function does the query and the filtering, and
 * logs what it would have sent.
 */
const SENDING_ENABLED = false;

/** Reminders examined per run. Keeps a single invocation bounded. */
const BATCH_LIMIT = 500;

interface QuietHours {
  start: string;
  end: string;
}

/** Wall-clock minutes-since-midnight for an instant in a named time zone. */
function minutesInZone(timezone: string, at: Date): number | null {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      hour12: false,
      hour: "2-digit",
      minute: "2-digit",
    }).formatToParts(at);

    const hour = Number(parts.find((p) => p.type === "hour")?.value);
    const minute = Number(parts.find((p) => p.type === "minute")?.value);
    if (Number.isNaN(hour) || Number.isNaN(minute)) {
      return null;
    }
    return hour * 60 + minute;
  } catch {
    // An unrecognized IANA zone should not take the whole run down.
    return null;
  }
}

function parseClock(value: string): number | null {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value);
  if (!match) {
    return null;
  }
  return Number(match[1]) * 60 + Number(match[2]);
}

/** Quiet hours wrap past midnight, e.g. 21:00 to 08:00. */
function isQuietNow(
  quietHours: QuietHours | undefined,
  timezone: string | undefined,
  at: Date,
): boolean {
  if (!quietHours || !timezone) {
    return false;
  }
  const now = minutesInZone(timezone, at);
  const start = parseClock(quietHours.start);
  const end = parseClock(quietHours.end);
  if (now === null || start === null || end === null) {
    return false;
  }
  return start <= end ? now >= start && now < end : now >= start || now < end;
}

/**
 * Finds reminders that have come due and notifies their owner.
 *
 * TODO before enabling delivery:
 *   - Decide where FCM tokens live and keep users/{uid}/settings/private
 *     authoritative; prune tokens that come back UNREGISTERED from sendEach.
 *   - Collapse several due reminders for one user into a single digest rather
 *     than one push per plant.
 *   - Respect the project's FCM quota, and back off on RESOURCE_EXHAUSTED.
 *   - Page past BATCH_LIMIT with a cursor so a backlog drains over several
 *     runs instead of being silently truncated.
 *   - Re-run skipped reminders once quiet hours end, rather than dropping them.
 */
export const generateDueReminderNotifications = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Etc/UTC",
    region: DEFAULT_REGION,
    retryCount: 0,
  },
  async () => {
    const now = new Date();

    const due = await db
      .collectionGroup("reminders")
      .where("status", "==", "open")
      .where("dueAt", "<=", Timestamp.fromDate(now))
      .orderBy("dueAt")
      .limit(BATCH_LIMIT)
      .get();

    if (due.empty) {
      logger.info("No reminders due");
      return;
    }

    // Group by owner so one user gets one decision, not one per reminder.
    const byUser = new Map<string, typeof due.docs>();
    for (const doc of due.docs) {
      // users/{uid}/reminders/{reminderId}
      const uid = doc.ref.parent.parent?.id;
      if (!uid) {
        continue;
      }
      const bucket = byUser.get(uid) ?? [];
      bucket.push(doc);
      byUser.set(uid, bucket);
    }

    let notified = 0;
    let skipped = 0;

    for (const [uid, reminders] of byUser) {
      const [profileSnapshot, settingsSnapshot] = await Promise.all([
        db.doc(`users/${uid}`).get(),
        db.doc(`users/${uid}/settings/private`).get(),
      ]);

      const profile = profileSnapshot.data() ?? {};
      const settings = settingsSnapshot.data() ?? {};
      const preferences = profile.notificationPreferences ?? {};
      const timezone = profile.homeLocation?.timezone as string | undefined;

      if (preferences.pushEnabled === false) {
        skipped += reminders.length;
        continue;
      }

      if (isQuietNow(preferences.quietHours, timezone, now)) {
        skipped += reminders.length;
        continue;
      }

      const tokens = (settings.fcmTokens as string[] | undefined) ?? [];
      if (tokens.length === 0) {
        skipped += reminders.length;
        continue;
      }

      const title =
        reminders.length === 1
          ? (reminders[0].data().title as string)
          : `${reminders.length} plants need you`;

      if (!SENDING_ENABLED || isEmulated) {
        logger.info("Would notify (delivery disabled)", {
          uid,
          title,
          reminderCount: reminders.length,
          tokenCount: tokens.length,
        });
        continue;
      }

      await getMessaging().sendEachForMulticast({
        tokens,
        notification: { title, body: "Open Raíces to log today's care." },
        data: { type: "reminders_due", count: String(reminders.length) },
      });

      const batch = db.batch();
      for (const reminder of reminders) {
        batch.set(
          reminder.ref,
          { lastNotifiedAt: FieldValue.serverTimestamp() },
          { merge: true },
        );
      }
      await batch.commit();
      notified += reminders.length;
    }

    logger.info("Reminder sweep finished", {
      examined: due.size,
      users: byUser.size,
      notified,
      skipped,
      deliveryEnabled: SENDING_ENABLED && !isEmulated,
    });
  },
);
