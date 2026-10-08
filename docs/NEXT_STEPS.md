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

- **Apple sign-in is hidden.** The button is off until an Apple Developer
  account exists. Google is enabled from `firebase.json`. When Apple comes
  back, iOS will need it beside Google.
- **`enablePushNotifications()` is never called.** It asks for permission and
  registers the FCM token, and the scheduled reminder function skips any user
  with no tokens — so reminders silently do nothing until it runs. The natural
  home is a prompt after the first plant is added, not on first launch.
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
- [ ] **Enable Apple sign-in** once the developer account exists, then put the button back on the auth screen. `signInWithApple()` is still in the repository. Firebase rejects it until these values are saved in [Authentication → Sign-in method → Apple](https://console.firebase.google.com/project/raices-care/authentication/providers). Never commit the `.p8` key.

  Apple Developer portal:

  1. Identifiers → App IDs: register `care.raices.app` and turn on Sign in with Apple.
  2. Identifiers → Services IDs: create the web client (for example `care.raices.app.signin`) and turn on Sign in with Apple. Configure it with domain `raices-care.firebaseapp.com` and return URL `https://raices-care.firebaseapp.com/__/auth/handler`.
  3. Keys: create a Sign in with Apple key, download the `.p8` once, and note the Key ID. The Team ID is on the Membership page.

  Firebase Apple provider fields, in the order the console asks for them:

  - Services ID — the identifier from step 2
  - Apple Team ID
  - Key ID
  - Private key — the contents of the `.p8`
- [ ] **Delete the old** `com.example.raices` **apps** from the Firebase project. The package is now `care.raices.app`.
- [ ] **Decide the dev/prod split.** The plan was `raices-dev` and `raices-prod` with a `.dev` applicationId suffix on debug builds. Nothing is configured yet; today there is one project for everything.
- [ ] **Deploy the backend** once the above is settled: rules, then indexes, then functions. Indexes take minutes to build and queries fail until they finish, so do them before anything that depends on them.
- [ ] **Seed the catalog** against the emulator first. See the README.
- [ ] **Turn on notification delivery** after testing. `SENDING_ENABLED` in `functions/src/reminders.ts` is `false`.
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

