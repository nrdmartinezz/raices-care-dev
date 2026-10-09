import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/core/api/api_config.dart';

void main() {
  test('debug builds may use localhost', () {
    final uri = resolveApiBaseUrl('http://localhost:8787', release: false);
    expect(uri.host, 'localhost');
    expect(uri.port, 8787);
  });

  test('release builds refuse a local API', () {
    expect(
      () => resolveApiBaseUrl('http://127.0.0.1:8787', release: true),
      throwsStateError,
    );
    expect(
      () => resolveApiBaseUrl('http://10.0.2.2:8787', release: true),
      throwsStateError,
    );
  });

  test('debug builds use the Worker without a define', () {
    expect(usesWorkerApi, isTrue);
    expect(kDebugMode, isTrue);
  });

  test('release builds accept a hosted API', () {
    final uri = resolveApiBaseUrl('https://api.raices.care', release: true);
    expect(uri.host, 'api.raices.care');
  });
}
