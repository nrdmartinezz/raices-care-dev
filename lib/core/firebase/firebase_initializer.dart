import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'emulator_config.dart';

/// Brings Firebase up once, before the widget tree is built.
///
/// Call [ensureInitialized] from `main` and nothing else; every feature reaches
/// Firebase through a repository, never by touching these instances directly.
abstract final class FirebaseInitializer {
  static Future<void> ensureInitialized() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (useFirebaseEmulators) {
      // App Check is skipped here: the debug provider still calls the live
      // App Check backend, which defeats the point of running offline.
      _connectEmulators();
    } else {
      await _activateAppCheck();
    }

    await _configureTelemetry();
  }

  static void _connectEmulators() {
    final host = emulatorHost;

    FirebaseAuth.instance.useAuthEmulator(host, EmulatorPorts.auth);
    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      EmulatorPorts.firestore,
    );
    FirebaseStorage.instance.useStorageEmulator(host, EmulatorPorts.storage);
    FirebaseFunctions.instance.useFunctionsEmulator(
      host,
      EmulatorPorts.functions,
    );

    debugPrint('Firebase: using emulators at $host');
  }

  /// Activates App Check with debug attestation locally and real attestation
  /// in release builds.
  ///
  /// Enforcement is a separate, manual switch in the Firebase console. Leave
  /// every service unenforced until a release build has been seen to pass, or
  /// real users will be locked out. See the README for the console steps.
  static Future<void> _activateAppCheck() async {
    if (!_supportsAppCheck) {
      return;
    }

    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? AndroidDebugProvider()
            : AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? AppleDebugProvider()
            : AppleAppAttestProvider(),
        // Supplied per build, because a reCAPTCHA site key is environment
        // specific. Web App Check stays off until one is provided.
        providerWeb: _recaptchaSiteKey.isEmpty
            ? null
            : ReCaptchaV3Provider(_recaptchaSiteKey),
      );
    } on FirebaseException catch (error) {
      // A missing provider registration should not stop the app from starting.
      debugPrint('Firebase: App Check unavailable (${error.code})');
    }
  }

  static Future<void> _configureTelemetry() async {
    // Debug runs stay out of the production dashboards, and crash reporting
    // never swallows the stack traces you want in the console.
    final collect = !kDebugMode;

    if (_supportsAnalytics) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(collect);
    }

    if (!_supportsCrashlytics) {
      return;
    }

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(collect);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  static const String _recaptchaSiteKey = String.fromEnvironment(
    'APP_CHECK_RECAPTCHA_SITE_KEY',
  );

  static bool get _supportsAppCheck {
    if (kIsWeb) {
      return _recaptchaSiteKey.isNotEmpty;
    }
    return const {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);
  }

  static bool get _supportsCrashlytics {
    if (kIsWeb) {
      return false;
    }
    return const {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);
  }

  static bool get _supportsAnalytics {
    if (kIsWeb) {
      return true;
    }
    return const {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);
  }
}
