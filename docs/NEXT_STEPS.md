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

Not done, and blocking real use: **there is no way to sign in.** Every
repository already calls `currentUserIdProvider`, so with no session they all
return empty streams. That is why the home screen shows empty states rather
than failing — but nothing can be created either.

---

## 1. Authentication (do this first)

Everything else depends on it. The repository and the profile document are
already written; what is missing is the UI and the routing.

### What already exists

`lib/features/auth/data/auth_repository.dart` has `signIn`, `createAccount`,
`sendPasswordReset`, `signOut`, `ensureProfileExists` and `watchProfile`.
`createAccount` also writes `/users/{uid}`, which is what fires the
`onUserCreated` function that fills in the defaults. Errors already arrive as
typed `AppException`s, so the screens can match on them instead of reading
Firebase error codes.

### Screens to build

Put them in `lib/features/auth/presentation/`, outside the shell — no bottom
nav on an auth screen.

| Screen | Route | Notes |
| --- | --- | --- |
| `sign_in_screen.dart` | `/sign-in` | Email, password, "forgot password" link |
| `sign_up_screen.dart` | `/sign-up` | Name, email, password, confirm |
| `reset_password_screen.dart` | `/reset-password` | Email only; always show the same confirmation |

Style them from `AppColors` / `AppText` so they match the home screen. There is
no text field style in `theme.dart` yet — add one there rather than per screen.

### Router changes

Add a `redirect` to `routerProvider` in `lib/app/router.dart`. The provider is
already a Riverpod `Provider`, so it can watch auth state:

```dart
final router = GoRouter(
  refreshListenable: ..., // see note below
  redirect: (context, state) {
    final signedIn = ref.read(authStateProvider).value != null;
    final goingToAuth = state.matchedLocation.startsWith('/sign-');
    if (!signedIn && !goingToAuth) return SignInRoute.path;
    if (signedIn && goingToAuth) return HomeRoute.path;
    return null;
  },
  // ...existing routes, plus the three auth routes outside the shell
);
```

Two details that are easy to get wrong:

- **go_router does not re-run `redirect` when a provider changes.** It needs a
  `Listenable`. Either bridge `authStateProvider` into a `ChangeNotifier`, or
  rebuild the router when auth state changes. Bridging is the better of the
  two: rebuilding the `GoRouter` throws away the navigation stack.
- **Do not redirect while auth state is still loading.** On a cold start
  `authStateProvider` is briefly `AsyncLoading` even for a signed-in user, and
  redirecting on that flashes the sign-in screen. Return `null` while loading
  and show a splash.

### After sign-in

Two calls belong in the post-sign-in path, not in a widget:

1. `authRepository.ensureProfileExists()` — covers accounts created before the
   profile document existed, and any provider where sign-up and first sign-in
   are the same event.
2. `userSettingsRepository.enablePushNotifications()` — asks for permission and
   registers the FCM token. The scheduled reminder function skips any user with
   no tokens, so reminders silently do nothing until this runs.

On **sign-out**, call `userSettingsRepository.removeDeviceToken(token)` before
`signOut()`. Otherwise the next person to use the device receives the previous
user's reminders.

### Worth deciding before building

- **Sign-in methods.** Email/password is scaffolded. Google and Apple sign-in
  need Console configuration, and Apple is mandatory on iOS if any other social
  provider is offered.
- **Anonymous accounts.** Letting someone try the app before registering is
  nice, but linking an anonymous account to a real one later is fiddly. Decide
  now; retrofitting it is much worse.
- **Email verification.** Currently unenforced. If it should gate anything, the
  check belongs in the router redirect and the Firestore rules together.

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

- [ ] **Rotate the Trefle API token.** The current one was pasted into a chat
      and is in an uploaded file. Replace it at trefle.io, then set the new one
      with `firebase functions:secrets:set TREFLE_API_TOKEN`. It must not go in
      any committed file.
- [ ] **Enable the Firestore API** on `raices-care`. It is still disabled, so
      nothing can deploy or be tested against the real project.
- [ ] **Delete the old `com.example.raices` apps** from the Firebase project.
      The package is now `care.raices.app`.
- [ ] **Decide the dev/prod split.** The plan was `raices-dev` and
      `raices-prod` with a `.dev` applicationId suffix on debug builds. Nothing
      is configured yet; today there is one project for everything.
- [ ] **Deploy the backend** once the above is settled: rules, then indexes,
      then functions. Indexes take minutes to build and queries fail until they
      finish, so do them before anything that depends on them.
- [ ] **Seed the catalog** against the emulator first. See the README.
- [ ] **Turn on notification delivery** after testing. `SENDING_ENABLED` in
      `functions/src/reminders.ts` is `false`.
- [ ] **Enforce App Check** only after a release build has been verified
      against it. Turning it on early locks out your own app.

---

## 5. Known gaps

Things that are deliberately incomplete, so nobody rediscovers them as bugs.

- **Weather is hard-coded.** The strip in `HomeTemplateContent` needs a
  forecast provider keyed on `users/{uid}.homeLocation`.
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
- **`google_fonts` fetches at runtime.** First launch offline shows fallback
  fonts. Bundling the `.ttf` files would fix it.
- **The logo has a cream background** slightly off from the header's `#FFF8F6`,
  so a faint square is visible. A transparent export fixes it.
- **Windows desktop does not build.** The Firebase C++ SDK needs CMake 3.22 and
  the installed Build Tools ship 3.20.
