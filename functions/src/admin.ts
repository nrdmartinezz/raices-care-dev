import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

// The Admin SDK bypasses Firestore and Storage rules. Everything in this
// codebase is therefore trusted server code, and must validate its own inputs.
if (getApps().length === 0) {
  initializeApp();
}

export const db = getFirestore();
export { FieldValue };

/** True while running under `firebase emulators:start`. */
export const isEmulated = process.env.FUNCTIONS_EMULATOR === "true";
