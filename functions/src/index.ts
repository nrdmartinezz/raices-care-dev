/**
 * Raíces trusted backend.
 *
 * Everything here runs with Admin SDK privileges and therefore bypasses the
 * Firestore and Storage rules. Each handler validates its own inputs.
 *
 * Nothing in this codebase is deployed automatically. See the Firebase section
 * of the README for the deploy commands and the secrets each function needs.
 */

export { onUserCreated } from "./users";
export { onPlantCreated } from "./plants";
export { onCareEventCreated } from "./care";
export { generateDueReminderNotifications } from "./reminders";
export { resolveSpecies, searchSpeciesCatalog } from "./catalog/resolve_species";
