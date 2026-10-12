import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/core/api/api_client.dart';
import 'package:raices/core/errors/app_exception.dart';

void main() {
  DioException failure(
    String method, {
    String? idempotencyKey,
    DioExceptionType? type,
    int? status,
  }) {
    return DioException(
      requestOptions: RequestOptions(
        path: '/v1/me',
        method: method,
        headers: {'Idempotency-Key': ?idempotencyKey},
      ),
      type: type ?? DioExceptionType.connectionError,
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/v1/me'),
              statusCode: status,
            ),
    );
  }

  test('a dropped PUT is retried once', () {
    expect(shouldRetryTransportFailure(failure('PUT')), isTrue);
  });

  test('a dropped POST is retried only with an idempotency key', () {
    expect(shouldRetryTransportFailure(failure('POST')), isFalse);
    expect(
      shouldRetryTransportFailure(failure('POST', idempotencyKey: 'plant-1')),
      isTrue,
    );
  });

  test('an HTTP error and a timeout are not retried', () {
    expect(shouldRetryTransportFailure(failure('PUT', status: 500)), isFalse);
    expect(
      shouldRetryTransportFailure(
        failure('PUT', type: DioExceptionType.connectionTimeout),
      ),
      isFalse,
    );
  });

  test('a signed-out rejection is not retried', () {
    final error = failure('PUT');
    expect(
      shouldRetryTransportFailure(
        DioException(
          requestOptions: error.requestOptions,
          type: DioExceptionType.unknown,
          error: const UnauthenticatedException(),
        ),
      ),
      isFalse,
    );
  });
}
