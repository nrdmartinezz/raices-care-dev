# Raíces

A Flutter plant-care app for flowers, fruiting trees, succulents, ornamental trees,
houseplants, herbs, and vegetables. Users add their own plants, get care reminders,
log care actions, upload photos, record observations, and browse a shared species catalog.

Firebase project: `raices-care`

Picking the work back up? Start with [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md).

## App identifiers

The Android `applicationId`, iOS bundle ID, and macOS bundle ID are all `care.raices.app`,
the reverse-DNS form of `raices.care`. These are permanent once the app ships: neither Google
Play nor the App Store allows changing them after the first release.

A `.dev` suffix for debug builds, so development and production can sit side by side on one
device, is planned for when separate dev and production Firebase projects exist. It is not
configured yet.

## Local tool paths

This machine runs the tooling from these locations. Adjust if yours differ.

| Tool | Path |
| --- | --- |
| Flutter SDK | `C:\flutter\bin\flutter.bat` |
| Android SDK | `%LOCALAPPDATA%\Android\sdk` |
| JDK 17 | `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot` |

`ANDROID_HOME` and `JAVA_HOME` are set for the current Windows user, so a newly opened
terminal picks them up automatically. Verify the toolchain with:

```powershell
C:\flutter\bin\flutter.bat doctor
```

## First-time setup

Install Dart and Flutter packages:

```powershell
C:\flutter\bin\flutter.bat pub get
```

Generate the Firebase client configuration. These files are deliberately untracked, so each
developer generates their own:

```powershell
flutterfire configure --project=raices-care
```

That writes `lib/firebase_options.dart` and `android/app/google-services.json`. Never commit
either one. See [Secrets and untracked files](#secrets-and-untracked-files).

Re-run the same command whenever an app identifier changes. The Google Services Gradle plugin
matches `google-services.json` against the `applicationId`, and the Android build fails with
"No matching client found for package name" when the two disagree.

## Running the app

### Android emulator

The emulator must be booted before Flutter will list it as a device. Flutter only supports
64-bit Android images, so the virtual device must use an `x86_64` system image.

Start the emulator on the host GPU, and skip quick boot. Software rendering (`-gpu swiftshader_indirect`)
stalls this machine: `opengl32sw` is missing, and restoring the quick-boot snapshot exits before adb
comes online.

```powershell
& "$env:ANDROID_HOME\emulator\emulator.exe" -avd raices_phone_64 -no-metrics -gpu host -no-snapshot-load
```

Wait for the Android home screen, then confirm the device is online:

```powershell
C:\flutter\bin\flutter.bat devices
```

Run the app:

```powershell
C:\flutter\bin\flutter.bat run -d emulator-5554
```

The first Android build runs a full Gradle build and takes several minutes. Later runs are fast.

### Chrome

Useful for quick UI work, and it needs no emulator:

```powershell
C:\flutter\bin\flutter.bat run -d chrome
```

### Windows desktop

Not currently supported. The Firebase C++ SDK requires CMake 3.22 or newer, and the installed
Visual Studio 2019 Build Tools ship CMake 3.20, so `flutter run -d windows` fails at the build
file generation step.

While an app is running, `r` hot-reloads, `R` hot-restarts, and `q` quits.

## Creating a new Android emulator

If `flutter emulators` lists nothing, install a 64-bit system image and create a device:

```powershell
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" "system-images;android-36;google_apis_playstore;x86_64"
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\avdmanager.bat" create avd -n raices_phone_64 -k "system-images;android-36;google_apis_playstore;x86_64" -d pixel
```

### Emulator troubleshooting

- **Flutter lists no Android device.** The emulator is not booted yet, or is still booting.
  Check with `adb devices`; it reports `offline` until Android finishes starting.
- **"Running multiple emulators with the same AVD".** A previous copy is still running.
  Stop the `emulator.exe` and `qemu-system-x86_64.exe` processes, then delete
  `%USERPROFILE%\.android\avd\raices_phone_64.avd\hardware-qemu.ini.lock`.
- **Device shows as `unsupported`.** The image is 32-bit. Create a new device from an
  `x86_64` system image.

## Secrets and untracked files

`.gitignore` excludes the generated Firebase client configuration and credential files:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist` and the macOS equivalent
- `.env` files, service-account JSON, and Firebase Admin SDK keys

Admin SDK credentials must never be used in the Flutter client. Server-trusted work belongs in
Cloud Functions.

The Trefle API token is a server-side secret. It is held in Cloud Secret Manager and read only
by Cloud Functions — see [Species catalog](#species-catalog). It must never reach the client,
a committed file, or a log line.

## Architecture

```
lib/
  app/           theme, router, root widget
    shell/       header, bottom nav, and the frame the tabs render into
  core/
    errors/      AppException hierarchy and the Firebase error mapper
    firebase/    initialization, emulator wiring, Riverpod providers
    utils/       lenient Firestore field readers
    widgets/     shared presentation pieces
  features/
    <feature>/
      domain/    immutable models with fromFirestore / toCreateJson
      data/      repositories — the only code that talks to Firebase
      presentation/
functions/src/   Cloud Functions (TypeScript)
```

Two rules hold the layers apart:

**Widgets never touch Firebase.** Every Firestore, Storage, Functions and Auth call goes
through a repository in a `data/` folder. Repositories are exposed as Riverpod providers and
wrap their calls in `guardFirebase`, which turns Firebase's string error codes into the typed
`AppException` subclasses in `core/errors`. UI code matches on those instead of parsing codes.

**The server owns derived state.** A plant's `currentCare` and `nextActions`, and the reminders
generated from a species care profile, are written by Cloud Functions, not by the app. Clients
record what happened — "I watered this" — and the triggers work out what follows. The Firestore
rules enforce this: those fields are rejected on a client write. So log a care event rather
than editing a plant's timestamps, and the reminder rolls forward on its own.

### Navigation

The four tabs — Home, My Plants, Chores, Wisdom — are branches of a go_router
`StatefulShellRoute`, so each keeps its own stack and scroll position as you move between
them. `AppShell` draws the frosted header and bottom nav over the active branch, which means
screen content has to pad itself clear of both: wrap it in `ShellScrollView` rather than doing
that by hand. The central add button is routed *outside* the shell, so it covers the nav and
reads as a task you finish or abandon.

Only Home is built. The other three render `PlaceholderView`, which also lists what each
screen is meant to do.

## Firebase backend

| File | Purpose |
| --- | --- |
| `firestore.rules` | Per-user isolation, shape validation, read-only catalog |
| `functions/src/images.ts` | Signs avatar and plant photo uploads to R2 |
| `firestore.indexes.json` | Composite and collection-group indexes |
| `functions/` | TypeScript Cloud Functions |

### Data model

```
species/{speciesId}/careProfiles|cultivars|sources    shared catalog, read-only to clients
plantCategories, careTaskTemplates, pestDiseaseCatalog
users/{uid}/plants/{plantId}/careEvents|photos|observations
users/{uid}/reminders, gardens, settings/private
publicProfiles, communityPosts                        reserved; denied for now
```

Catalog collections are world-readable and client-unwritable. Everything under `users/{uid}`
is readable and writable only by that user, with per-field validation. Care events are
append-only: the rules allow create and delete but not update, so a mis-logged event is
deleted and re-logged rather than silently rewritten.

### Functions

| Function | Trigger | What it does |
| --- | --- | --- |
| `onUserCreated` | `users/{uid}` created | Fills in defaults and the private settings doc |
| `onPlantCreated` | plant created | Resolves the care profile and seeds reminders |
| `onCareEventCreated` | care event created | Advances the plant and rolls its reminder forward |
| `generateDueReminderNotifications` | every 15 min | Finds due reminders, respects quiet hours |
| `resolveSpecies` | callable | Caches a species from Trefle into `/species` |
| `searchSpeciesCatalog` | callable | Searches Trefle; writes nothing |
| `prepareImageUpload` | callable | Signs a JPEG upload to R2 for the signed-in user |
| `deleteImage` | callable | Deletes one of that user's objects from R2 |

Notification delivery is **off**. `functions/src/reminders.ts` sets `SENDING_ENABLED = false`,
so the sweep logs what it would send instead of sending it. Flip that only after testing
against the emulator.

Build them before anything else, since the emulator serves compiled output from `lib/`:

```powershell
cd functions; npm install; npm run build; cd ..
```

## Emulator Suite

Run the whole backend locally. Nothing here touches the real project.

```powershell
firebase emulators:start
```

Ports: Auth 9099, Firestore 8080, Functions 5001, UI at <http://localhost:4000>.

The app only connects to the emulators when told to, so a normal `flutter run` still points at
the real project:

```powershell
C:\flutter\bin\flutter.bat run -d emulator-5554 --dart-define=USE_FIREBASE_EMULATORS=true
```

Two details worth knowing. The Android emulator reaches the host at `10.0.2.2` rather than
`localhost`, which `core/firebase/emulator_config.dart` handles for you. And App Check is
skipped entirely in emulator mode — even its debug provider calls the live App Check backend,
which defeats the point of running offline.

## Species catalog

Species data comes from [Trefle](https://trefle.io) under **CC-BY-4.0**. That licence has a
condition the app must meet: wherever species data appears, the UI has to credit the source.
`searchSpeciesCatalog` returns the required string in its `attribution` field, and each cached
species stores its own provenance in `species/{id}/sources/{sourceId}`. Show it.

The catalog fills in lazily. Searching hits Trefle live and writes nothing; `resolveSpecies`
caches a record the first time a user actually adds that plant, with a 90-day refresh window.
Species ids are our own slugs, with upstream ids kept in an `externalIds` map — Trefle's v1 API
sunsets on 31 January 2027, and the slug-based ids mean swapping in a successor such as Flora
Codex is a mapper change rather than a migration.

Trefle carries no care instructions, only growth tolerances. `functions/src/catalog/species_mapper.ts`
turns those into watering and feeding cadences, and each derived task records a `basis` array
naming the fields it used. An empty `basis` means the record was too sparse and the task fell
back to a default — worth surfacing differently in the UI, since it is a guess rather than a
species-specific recommendation.

### Seeding a sample catalog

`functions/src/scripts/seed_catalog.ts` loads about 200 species. It searches a curated term
list rather than paging `/plants`, because that endpoint is dominated by wild flora — oaks,
nettles, clovers and grasses — which a plant-care app has no use for.

It refuses to run against production unless you pass `--allow-production`, so point it at the
emulator:

```powershell
$env:FIRESTORE_EMULATOR_HOST = "localhost:8080"
$env:TREFLE_API_TOKEN = "<your token>"
cd functions; npm run seed
```

Set the token for a single shell only. Do not put it in a file.

## Deploying

Nothing deploys automatically. Review each artifact, then deploy it deliberately.

Store the secrets first. The catalog callables will not start without the Trefle token, and image uploads will not start without the R2 token:

```powershell
firebase functions:secrets:set TREFLE_API_TOKEN
firebase functions:secrets:set R2_ACCESS_KEY_ID
firebase functions:secrets:set R2_SECRET_ACCESS_KEY
```

```powershell
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only functions
```

Indexes take minutes to build; queries that need them fail until they finish. Deploy indexes
before the functions and screens that depend on them.

App Check is scaffolded but **not enforced**. The client registers debug providers in debug
builds and Play Integrity / App Attest in release, but enforcement in the Firebase Console
stays off until a release build has been verified against it — turning it on early locks out
your own app.

## Flutter resources

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Flutter documentation](https://docs.flutter.dev/)
- [Add Firebase to a Flutter app](https://firebase.google.com/docs/flutter/setup)
