import { importPKCS8, SignJWT } from "jose";
import { pushIsDryRun, type Env } from "../env";
import { now } from "../http/ids";
import { listDueReminders, type DueReminder } from "./reminders";

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id?: string;
};

const DAY = 24 * 60 * 60 * 1000;
const QUIET_START = 21 * 60;
const QUIET_END = 8 * 60;
const CHECKIN_ID = "checkin";
const IDLE_AFTER = 4 * DAY;
const CHECKIN_GAP = 7 * DAY;

export type CareNotice = {
  userId: string;
  title: string;
  body: string;
  kind: "chores" | "checkin";
};

const CHECKIN_NOTICE = {
  title: "Your garden misses you",
  body: "It's been a few days. Open Raíces and see how things are growing.",
};

/**
 * One message per person for everything newly due, then a check-in for
 * someone who has not opened the app in four days. FCM is called only when a
 * service account is configured and DRY_RUN_PUSH is "false".
 */
export async function runReminderCron(
  env: Env,
  asOf = now(),
): Promise<{ considered: number; dryRun: boolean; messages: CareNotice[] }> {
  const dryRun = pushIsDryRun(env);
  const due = await listDueReminders(env, asOf);
  const messages: CareNotice[] = [];
  const digested = new Set<string>();

  const byUser = new Map<string, DueReminder[]>();
  for (const reminder of due) {
    const bucket = byUser.get(reminder.user_id) ?? [];
    bucket.push(reminder);
    byUser.set(reminder.user_id, bucket);
  }

  for (const [userId, reminders] of byUser) {
    const notice = await deliverChores(env, userId, reminders, dryRun, asOf);
    if (notice) {
      messages.push(notice);
      digested.add(userId);
    }
  }

  messages.push(...(await deliverCheckIns(env, dryRun, asOf, digested)));

  return { considered: due.length, dryRun, messages };
}

async function deliverChores(
  env: Env,
  userId: string,
  reminders: DueReminder[],
  dryRun: boolean,
  asOf: number,
): Promise<CareNotice | null> {
  const pending: DueReminder[] = [];
  for (const reminder of reminders) {
    const existing = await deliveryStatus(env, userId, reminder.id, reminder.due_at);
    if (existing === "sent" || existing === "skipped") continue;
    if (existing === "dry_run" && dryRun) continue;
    pending.push(reminder);
  }
  if (pending.length === 0) return null;

  const timezone = await userTimezone(env, userId);
  if (isQuietHours(timezone, new Date(asOf))) return null;

  const tokens = await deviceTokens(env, userId);
  if (tokens.length === 0) return null;

  const copy = choreCopy(pending);
  const status = dryRun ? "dry_run" : "sent";
  if (!dryRun) {
    const delivered = await sendToTokens(env, tokens, copy.title, copy.body, { type: "chores" });
    if (!delivered) return null;
  }

  for (const reminder of pending) {
    await recordDelivery(env, userId, reminder.id, reminder.due_at, status, asOf);
  }
  if (dryRun) {
    console.log(
      JSON.stringify({
        message: "push_dry_run",
        userId,
        title: copy.title,
        reminderCount: pending.length,
        tokens: tokens.length,
      }),
    );
  }
  return { userId, ...copy, kind: "chores" };
}

async function deliverCheckIns(
  env: Env,
  dryRun: boolean,
  asOf: number,
  skip: Set<string>,
): Promise<CareNotice[]> {
  const idleSince = asOf - IDLE_AFTER;
  const sentSince = asOf - CHECKIN_GAP;
  const rows = await env.DB.prepare(
    `SELECT u.id, u.timezone
     FROM users u
     WHERE u.deleted_at IS NULL
       AND u.last_opened_at IS NOT NULL
       AND u.last_opened_at <= ?
       AND EXISTS (SELECT 1 FROM device_tokens t WHERE t.user_id = u.id)
       AND NOT EXISTS (
         SELECT 1 FROM notification_deliveries d
         WHERE d.user_id = u.id
           AND d.reminder_id = ?
           AND d.created_at >= ?
           AND d.status IN ('sent', 'dry_run')
       )
     LIMIT 100`,
  )
    .bind(idleSince, CHECKIN_ID, sentSince)
    .all<{ id: string; timezone: string | null }>();

  const messages: CareNotice[] = [];
  for (const user of rows.results ?? []) {
    if (skip.has(user.id)) continue;
    if (isQuietHours(user.timezone, new Date(asOf))) continue;
    const tokens = await deviceTokens(env, user.id);
    if (tokens.length === 0) continue;

    const status = dryRun ? "dry_run" : "sent";
    if (!dryRun) {
      const delivered = await sendToTokens(env, tokens, CHECKIN_NOTICE.title, CHECKIN_NOTICE.body, {
        type: "chores",
      });
      if (!delivered) continue;
    }
    await recordDelivery(env, user.id, CHECKIN_ID, asOf, status, asOf);
    messages.push({ userId: user.id, ...CHECKIN_NOTICE, kind: "checkin" });
  }
  return messages;
}

function choreCopy(reminders: DueReminder[]): { title: string; body: string } {
  if (reminders.length === 1) {
    return {
      title: reminders[0].title,
      body: "Open Raíces to log today's care.",
    };
  }
  const watering = reminders.some((reminder) => reminder.task_type === "water_check");
  return {
    title: `${reminders.length} chores are ready`,
    body: watering
      ? "Including watering. Open Raíces to log today's care."
      : "Open Raíces to log today's care.",
  };
}

/** 21:00–08:00 in the gardener's time zone. An unknown zone does not hold the reminder. */
function isQuietHours(timezone: string | null, at: Date): boolean {
  if (!timezone) return false;
  const minutes = minutesInZone(timezone, at);
  if (minutes === null) return false;
  return minutes >= QUIET_START || minutes < QUIET_END;
}

function minutesInZone(timezone: string, at: Date): number | null {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      hour12: false,
      hour: "2-digit",
      minute: "2-digit",
    }).formatToParts(at);
    let hour = Number(parts.find((part) => part.type === "hour")?.value);
    const minute = Number(parts.find((part) => part.type === "minute")?.value);
    if (hour === 24) hour = 0;
    if (Number.isNaN(hour) || Number.isNaN(minute)) return null;
    return hour * 60 + minute;
  } catch {
    return null;
  }
}

async function userTimezone(env: Env, userId: string): Promise<string | null> {
  const row = await env.DB.prepare("SELECT timezone FROM users WHERE id = ?")
    .bind(userId)
    .first<{ timezone: string | null }>();
  return row?.timezone ?? null;
}

async function deviceTokens(env: Env, userId: string): Promise<string[]> {
  const tokens = await env.DB.prepare("SELECT token FROM device_tokens WHERE user_id = ?")
    .bind(userId)
    .all<{ token: string }>();
  return (tokens.results ?? []).map((row) => row.token);
}

async function deliveryStatus(
  env: Env,
  userId: string,
  reminderId: string,
  dueAt: number,
): Promise<string | null> {
  const existing = await env.DB.prepare(
    `SELECT status FROM notification_deliveries
     WHERE user_id = ? AND reminder_id = ? AND due_at = ?`,
  )
    .bind(userId, reminderId, dueAt)
    .first<{ status: string }>();
  return existing?.status ?? null;
}

async function recordDelivery(
  env: Env,
  userId: string,
  reminderId: string,
  dueAt: number,
  status: string,
  createdAt: number,
): Promise<void> {
  const existing = await deliveryStatus(env, userId, reminderId, dueAt);
  if (!existing) {
    await env.DB.prepare(
      `INSERT INTO notification_deliveries
        (id, user_id, reminder_id, due_at, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id, reminder_id, due_at) DO NOTHING`,
    )
      .bind(crypto.randomUUID(), userId, reminderId, dueAt, status, createdAt)
      .run();
    return;
  }
  if (status === "sent") {
    await env.DB.prepare(
      `UPDATE notification_deliveries SET status = 'sent'
       WHERE user_id = ? AND reminder_id = ? AND due_at = ?`,
    )
      .bind(userId, reminderId, dueAt)
      .run();
  }
}

async function sendToTokens(
  env: Env,
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<boolean> {
  let delivered = false;
  for (const token of tokens) {
    if (await sendFcm(env, token, title, body, data)) delivered = true;
  }
  return delivered;
}

async function sendFcm(
  env: Env,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<boolean> {
  try {
    const account = JSON.parse(env.FCM_SERVICE_ACCOUNT_JSON ?? "") as ServiceAccount;
    const accessToken = await googleAccessToken(account);
    const projectId = account.project_id || env.FIREBASE_PROJECT_ID;
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data,
          },
        }),
      },
    );
    if (!response.ok) {
      console.log(JSON.stringify({ message: "push_failed", status: response.status }));
      return false;
    }
    return true;
  } catch (error) {
    console.log(JSON.stringify({ message: "push_failed", error: String(error) }));
    return false;
  }
}

async function googleAccessToken(account: ServiceAccount): Promise<string> {
  const key = await importPKCS8(account.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error("FCM auth failed");
  }
  const body = (await response.json()) as { access_token?: string };
  if (!body.access_token) throw new Error("FCM auth failed");
  return body.access_token;
}
