# Raíces

A Flutter plant-care app for flowers, fruiting trees, succulents, ornamental trees,
houseplants, herbs, and vegetables. Users add their own plants, get care reminders,
log care actions, upload photos, record observations, and browse a shared species catalog.

Firebase project: `raices-care`

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

Start the emulator. The software graphics flag is required on this machine, because booting on
the host GPU path fails:

```powershell
& "$env:ANDROID_HOME\emulator\emulator.exe" -avd raices_phone_64 -no-metrics -gpu swiftshader_indirect
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

## Flutter resources

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Flutter documentation](https://docs.flutter.dev/)
- [Add Firebase to a Flutter app](https://firebase.google.com/docs/flutter/setup)
