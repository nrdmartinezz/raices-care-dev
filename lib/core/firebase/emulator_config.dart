import 'package:flutter/foundation.dart';

/// Emulator ports. These must stay in step with the `emulators` block in
/// firebase.json.
abstract final class EmulatorPorts {
  static const auth = 9099;
  static const firestore = 8080;
  static const functions = 5001;
}

/// Opted into per run, never baked into a build:
///
///   flutter run --dart-define=USE_FIREBASE_EMULATORS=true
const bool _emulatorsRequested = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

/// Host override for a physical device, which cannot reach the host loopback:
///
///   --dart-define=FIREBASE_EMULATOR_HOST=192.168.1.20
const String _hostOverride = String.fromEnvironment('FIREBASE_EMULATOR_HOST');

/// Whether this run should talk to the emulator suite.
///
/// The `kDebugMode` guard is the important half: a release build points at the
/// real project even if the define is somehow set.
bool get useFirebaseEmulators => kDebugMode && _emulatorsRequested;

/// Where the emulators are listening, from the app's point of view.
///
/// The Android emulator reaches the host machine through 10.0.2.2 rather than
/// localhost. The iOS simulator and desktop share the host's loopback.
String get emulatorHost {
  if (_hostOverride.isNotEmpty) {
    return _hostOverride;
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return '10.0.2.2';
  }
  return 'localhost';
}
