import 'package:flutter/foundation.dart';

/// Set with `--dart-define=API_BASE_URL=...`.
///
/// A debug build with no define uses the local Worker. Release builds still
/// require a hosted URL, and an empty release URL keeps the Firestore path.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

bool get usesWorkerApi => apiBaseUrl.isNotEmpty || kDebugMode;

/// Release builds must name a hosted API. Debug may use localhost, and the
/// Android emulator reaches the host at 10.0.2.2.
Uri resolveApiBaseUrl(String raw, {required bool release}) {
  if (raw.isEmpty) {
    throw StateError('API_BASE_URL is not set.');
  }
  final uri = Uri.parse(raw);
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw StateError('API_BASE_URL must be an absolute URL.');
  }
  final local =
      uri.host == 'localhost' ||
      uri.host == '127.0.0.1' ||
      uri.host == '10.0.2.2';
  if (release && local) {
    throw StateError('Release builds need a hosted API_BASE_URL.');
  }
  return uri;
}

Uri get configuredApiBase {
  if (apiBaseUrl.isNotEmpty) {
    return resolveApiBaseUrl(apiBaseUrl, release: kReleaseMode);
  }
  if (kDebugMode) return localWorkerBase();
  throw StateError('API_BASE_URL is not set.');
}

/// The Worker on this machine. Android emulator traffic uses 10.0.2.2.
Uri localWorkerBase() {
  final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';
  return Uri.parse('http://$host:8787');
}

/// Where sowing calendars are loaded from.
///
/// Debug builds use [configuredApiBase]. A release build with no hosted URL
/// has no calendar API.
Uri? get plantingApiBase {
  if (apiBaseUrl.isEmpty && !kDebugMode) return null;
  return configuredApiBase;
}
