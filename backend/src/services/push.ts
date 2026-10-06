import { importPKCS8, SignJWT } from "jose";
import { pushIsDryRun, type Env } from "../env";
import { now } from "../http/ids";
import { listDueReminders, type DueReminder } from "./reminders";

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id?: string;
};

/**
 * Records one delivery per reminder due time. FCM is called only when a
 * service account is configured and DRY_RUN_PUSH is "false".
 */
export async function runReminderCron(env: Env): Promise<{ considered: number; dryRun: boolean }> {
  const dryRun = pushIsDryRun(env);
  const due = await listDueReminders(env);
  for (const reminder of due) {
    await deliverReminder(env, reminder, dryRun);
  }
  return { considered: due.length, dryRun };
}

async function deliverReminder(env: Env, reminder: DueReminder, dryRun: boolean): Promise<void> {
  const existing = await env.DB.prepare(
    `SELECT status FROM notification_deliveries
     WHERE user_id = ? AND reminder_id = ? AND due_at = ?`,
  )
    .bind(reminder.user_id, reminder.id, reminder.due_at)
    .first<{ status: string }>();

  if (existing?.status === "sent" || existing?.status === "skipped") return;
  if (existing?.status === "dry_run" && dryRun) return;

  const tokens = await env.DB.prepare(
    "SELECT token FROM device_tokens WHERE user_id = ?",
  )
    .bind(reminder.user_id)
    .all<{ token: string }>();
  const deviceTokens = (tokens.results ?? []).map((row) => row.token);
  const status = deviceTokens.length === 0 ? "skipped" : dryRun ? "dry_run" : "sent";

  if (!existing) {
    await env.DB.prepare(
      `INSERT INTO notification_deliveries
        (id, user_id, reminder_id, due_at, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id, reminder_id, due_at) DO NOTHING`,
    )
      .bind(crypto.randomUUID(), reminder.user_id, reminder.id, reminder.due_at, status, now())
      .run();
  } else if (status === "sent") {
    await env.DB.prepare(
      `UPDATE notification_deliveries SET status = 'sent'
       WHERE user_id = ? AND reminder_id = ? AND due_at = ?`,
    )
      .bind(reminder.user_id, reminder.id, reminder.due_at)
      .run();
  }

  if (status !== "sent") {
    console.log(
      JSON.stringify({
        message: "push_dry_run",
        userId: reminder.user_id,
        reminderId: reminder.id,
        title: reminder.title,
        tokens: deviceTokens.length,
        status,
      }),
    );
    return;
  }

  for (const token of deviceTokens) {
    await sendFcm(env, token, reminder);
  }
}

async function sendFcm(env: Env, token: string, reminder: DueReminder): Promise<void> {
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
          notification: {
            title: reminder.title,
            body: "A plant care reminder is due.",
          },
          data: {
            reminderId: reminder.id,
            plantId: reminder.plant_id,
            taskType: reminder.task_type,
          },
        },
      }),
    },
  );
  if (!response.ok) {
    console.log(
      JSON.stringify({
        message: "push_failed",
        status: response.status,
        reminderId: reminder.id,
      }),
    );
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
