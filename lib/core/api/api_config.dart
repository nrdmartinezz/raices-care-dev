import 'package:flutter/foundation.dart';

/// Set with `--dart-define=API_BASE_URL=...`. Empty keeps the Firestore repositories.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

bool get usesWorkerApi => apiBaseUrl.isNotEmpty;

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

Uri get configuredApiBase =>
    resolveApiBaseUrl(apiBaseUrl, release: kReleaseMode);
