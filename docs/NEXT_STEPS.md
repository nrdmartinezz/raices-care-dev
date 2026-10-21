# Next steps

Written at the end of the Firebase scaffolding pass. Read `README.md` first for
setup and architecture; this file is only about what is left to do.

## Where things stand

Done:

- Figma home screen, built against the real design
- Firestore and Storage rules, composite indexes, emulator config
- Cloud Functions: user bootstrap, plant bootstrap, care-event effects, the
scheduled reminder sweep, and the Trefle catalog callables
- Dart client layer: typed models, seven repositories, Firebase initialization
- Home screen reading live Firestore data, with loading, empty and error states
- Shell with four tabs; three are styled placeholders
- Auth screen, built against the Figma design, with the router gate behind it

Not done, and blocking real use: **nothing writes data yet.** Signing in works,
but there is no way to add a plant, so every list stays empty. Section 2 is the
thing to build next.

---



## 1. Authentication (done)

One screen serves `/sign-in` and `/sign-up`, toggling between the two modes,
with a `/splash` that holds while the session resolves. The redirect in
`lib/app/router.dart` is the only place that checks for a session, so no screen
has to.

### What is wired

- `AuthRepository` — `signIn`, `createAccount`, `sendPasswordReset`, `signOut`,
`signInWithGoogle`, `signInWithApple`, `ensureProfileExists`, `watchProfile`.
The social methods use `firebase_auth`'s own `signInWithProvider`, with a
`signInWithPopup` branch for web, so there is no extra package to keep in
step with the SDK.
- `authStatusProvider` — a three-state enum: `unknown`, `signedOut`,
`signedIn`. The redirect reads this rather than `User?`, which also lets a
test state the session without constructing a Firebase user. The `unknown`
case holds on the splash; treating it as signed out flashes the sign-in
screen at a returning user on every cold start.
- `AuthController` — an `AsyncNotifier` holding the busy flag and the last
error. `SignInCancelledException` is swallowed on purpose: backing out of the
provider sheet is not a failure and should not turn the form red.
- Sign-up sends a verification email, but nothing is gated on it. If that
should change, the check belongs in the redirect and the Firestore rules
together, not in a widget.



### What is left

- **Apple sign-in is on.** The button sits beside Google on every platform. Firebase
still rejects the provider until the Services ID, Team ID, Key ID, and
`.p8` are saved. See the operational task below.
- **Push asks after the first plant.** `enablePushNotifications()` runs once
that plant is saved. On iOS it waits for the APNs token, then registers the
FCM token with the Worker at `POST /v1/me/devices`. Later launches refresh a
token that was already allowed. Web does not prompt. The Worker cron sends
reminders, and it stays a dry run until `FCM_SERVICE_ACCOUNT_JSON` is set.
See the operational task below.
- **No account screen.** `showAccountSheet` in
`lib/app/shell/account_sheet.dart` is a stand-in behind the header's profile
button: it shows who is signed in and signs them out. Sign-out already drops
this device's FCM token first, so the next person to sign in on the phone
does not inherit the previous user's reminders.
- **No anonymous accounts**, by decision. Linking an anonymous account to a
real one later is fiddly; revisit only if onboarding drop-off demands it.

---



## 2. Add a plant

The central nav button already routes to `AddPlantScreen`, which is a
placeholder. This is the first flow that writes data, and the first real use of
the lazy species cache.

The order matters:

1. Search with `speciesRepository.search(query)`. This hits Trefle live and
  writes nothing. Show the returned `attribution` string — the CC-BY-4.0
   licence requires it.
2. When the user picks a candidate, call `speciesRepository.resolve(...)`. That
  caches the species into `/species` and returns the id. **Do this before
   creating the plant**, or `onPlantCreated` finds no care profile, writes
   `catalogStatus: species_missing`, and seeds no reminders.
3. Collect the rest: name, location, pot, light.
4. `plantRepository.createPlant(plant)`.

Reminders appear a moment later, written by the trigger. The UI should not wait
on them — the plant stream updates on its own.

Flag low-confidence care advice. A derived care profile task with an empty
`basis` array means the Trefle record was too sparse and the cadence is a
default, not a species-specific recommendation.

---



## 3. The other three tabs

In rough order of value:

- **My Plants** — a list from `activePlantsProvider`, then a plant detail screen
with care history, photos and observations. Detail is where photo upload
lands; `PhotoRepository.uploadPhoto` takes `Uint8List`, so add `image_picker`
and pass `readAsBytes()`.
- **Chores** — the week ahead from `ReminderRepository.watchOpen()`, with
snooze, skip and add. Remember that **logging a care event is the preferred
way to complete a recurring reminder**: the trigger rolls it forward and
updates the plant together. `complete()` only marks it done.
- **Wisdom** — species browse and search, and the pest/disease catalog. Both
collections are world-readable, so this needs no new rules.

---



## 4. Operational tasks

These need a person in a console or a terminal, not code.

- [ ] **Rotate the Trefle API token.** The current one was pasted into a chat and is in an uploaded file. Replace it at trefle.io, then set the new one with `firebase functions:secrets:set TREFLE_API_TOKEN`. It must not go in any committed file.
- [ ] **Enable the Firestore API** on `raices-care`. It is still disabled, so nothing can deploy or be tested against the real project.
- [x] **Google sign-in** is enabled in `firebase.json` (`emailPassword` stays on, and `localhost` is an authorized domain). Deploy with `npx -y firebase-tools@latest deploy --only auth`.
- [x] **Finish Apple sign-in in Firebase.** The iOS button is already on. Firebase rejects it until these values are saved in [Authentication → Sign-in method → Apple](https://console.firebase.google.com/project/raices-care/authentication/providers). Never commit the `.p8` key. None of the certificate types (Apple Development, Apple Distribution, iOS Distribution, push SSL) are used here. App Store signing stays automatic in Xcode with team `7M3MHV2QK9`.
  Apple Developer portal, in this order. Each item is a different sidebar page:
  1. Identifiers → App IDs: `care.raices.app` with Sign in with Apple enabled. Saving this capability downloads nothing.
  2. Identifiers, then the filter at the top right: switch it from App IDs to Services IDs. An empty list means it has not been created. Click the blue plus, choose Services IDs, and register one (identifier `care.raices.app.signin`, description `Raíces Sign in with Apple`). Open it, enable Sign in with Apple, click Configure, and set domain `raices-care.firebaseapp.com` and return URL `https://raices-care.firebaseapp.com/__/auth/handler`. The identifier string is the Services ID. This screen does not download a file.
  3. Keys: click the blue plus, enable Sign in with Apple, and register. This is the only step that downloads a `.p8`. Apple shows the download once; if that page was closed, revoke the key and create a new one. Note the Key ID on the key’s detail page. Team ID is on the Membership page (`7M3MHV2QK9`).
  Firebase Apple provider fields, in the order the console asks for them:
  - Services ID — `care.raices.app.signin`, not the bundle ID
  - Apple Team ID — `7M3MHV2QK9`
  - Key ID
  - Private key — the contents of the `.p8`

- [x] **App Store Connect listing**, after a TestFlight build exists. Create the app with bundle ID `care.raices.app`, name `Raíces`, primary category Lifestyle. Then fill in:
  - A public privacy policy URL. Required before review. It should cover email and password accounts, Google and Apple sign-in, plant photos, care logs, Firebase Analytics, and Crashlytics. This repo does not host that page.
  - App Privacy answers: contact info (email), user content (photos and notes), identifiers, and diagnostics.
  - Screenshots for a 6.9-inch or 6.7-inch iPhone, the 1024 icon already in the asset catalog, a short description, a support URL, and an age rating.
  - Review notes: a test account email and password, and that account deletion is in account settings.
  - Push is requested after the first plant. Do not promise reminders in the listing until an APNs key is in Firebase, `FCM_SERVICE_ACCOUNT_JSON` is set on the Worker, and that Worker is deployed. `Info.plist` already declares remote notifications.
  Build with `flutter build ipa --release`, then upload the IPA with Xcode Organizer or Transporter. Put the build on TestFlight and sign in with Apple and with Google on a device before submitting for review. `ITSAppUsesNonExemptEncryption` is false, so the export-compliance prompt is already answered.
- [x] **Delete the old** `com.example.raices` **apps** from the Firebase project. The package is now `care.raices.app`.
- [ ] **Decide the dev/prod split.** The plan was `raices-dev` and `raices-prod` with a `.dev` applicationId suffix on debug builds. Nothing is configured yet; today there is one project for everything.
- [x] **Deploy the backend** once the above is settled: rules, then indexes, then functions. Indexes take minutes to build and queries fail until they finish, so do them before anything that depends on them.
- [ ] **Seed the catalog** against the emulator first. See the README.
- [x] **Turn on notification delivery.** The Worker cron is the sender. `DRY_RUN_PUSH` in `backend/wrangler.jsonc` is already `"false"`, and delivery stays a dry run until `FCM_SERVICE_ACCOUNT_JSON` is set with `npx wrangler secret put FCM_SERVICE_ACCOUNT_JSON` from `backend/`. Upload an APNs Auth Key in Firebase (Project settings → Cloud Messaging → Apple app). That key is not the Sign in with Apple key. Do not commit either `.p8` or the service account. Deploy the Worker only when the live cron should start. `SENDING_ENABLED` in `functions/src/reminders.ts` stays `false`; that function is not the sender.
- [ ] **Enforce App Check** only after a release build has been verified against it. Turning it on early locks out your own app.

---



## 5. Known gaps

Things that are deliberately incomplete, so nobody rediscovers them as bugs.

- **Weather is hard-coded.** The strip in `HomeTemplateContent` needs a
forecast provider keyed on `users/{uid}.homeLocation`. [https://www.weather.gov/documentation/services-web-API](https://www.weather.gov/documentation/services-web-API)
- **The tradition card is hard-coded.** It needs a wisdom collection.
- **"Done today" is approximate.** `careActionsToday` counts care actions from
each plant's `currentCare` timestamps, because the trigger rolls a completed
reminder forward instead of leaving it on today's list. Counting the care
events directly would need a collection-group query, which would in turn need
its own security rule.
- **Four tag colours for eight task types.** `CareCategory.forTaskType` folds
them together. Add tag icons to the design before splitting them apart.
- **Deleting a plant does not cascade.** Its careEvents, photos, observations
and reminders survive. That cleanup belongs in a Cloud Function so a partial
failure cannot leave orphans.
- `google_fonts` **fetches at runtime.** First launch offline shows fallback
fonts. Bundling the `.ttf` files would fix it.
- **The logo has a cream background** slightly off from the header's `#FFF8F6`,
so a faint square is visible. A transparent export fixes it.
- **Windows desktop does not build.** The Firebase C++ SDK needs CMake 3.22 and
the installed Build Tools ship 3.20.

