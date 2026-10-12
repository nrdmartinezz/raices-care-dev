import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../errors/app_exception.dart';
import 'api_config.dart';

/// A status-0 failure on an idempotent call is worth one more try.
///
/// Chrome on a phone often fails the first cross-origin request and then
/// succeeds. POST is included only when it carries an idempotency key, so a
/// retry cannot create a second plant or care event.
bool shouldRetryTransportFailure(DioException error) {
  if (error.response != null || error.error is AppException) {
    return false;
  }
  final dropped =
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.unknown;
  if (!dropped) {
    return false;
  }
  final method = error.requestOptions.method.toUpperCase();
  if (method == 'GET' ||
      method == 'HEAD' ||
      method == 'PUT' ||
      method == 'DELETE') {
    return true;
  }
  final key = error.requestOptions.headers['Idempotency-Key'];
  return key is String && key.isNotEmpty;
}

/// Talks to the Worker. Every request carries the current Firebase ID token.
class ApiClient {
  ApiClient({Dio? dio, required this._auth, Uri? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: (baseUrl ?? configuredApiBase).toString(),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'content-type': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final user = _auth.currentUser;
          if (user == null) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: const UnauthenticatedException(),
              ),
            );
            return;
          }
          final token = await user.getIdToken();
          options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _send(
      () => _dio.get<dynamic>(path, queryParameters: query),
    );
    return _object(response.data);
  }

  Future<Map<String, dynamic>> sendJson(
    String method,
    String path, {
    Object? body,
    String? idempotencyKey,
    String? ifMatch,
  }) async {
    final response = await _send(
      () => _dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: {'Idempotency-Key': ?idempotencyKey, 'If-Match': ?ifMatch},
        ),
      ),
    );
    if (response.data == null || response.data == '') {
      return const {};
    }
    return _object(response.data);
  }

  Future<Uint8List> getBytes(String path) async {
    final response = await _send(
      () => _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      ),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<Map<String, dynamic>> postBytes(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    final response = await _send(
      () => _dio.post<dynamic>(
        path,
        data: bytes,
        options: Options(
          headers: {'content-type': contentType},
          contentType: contentType,
        ),
      ),
    );
    return _object(response.data);
  }

  Future<Response<T>> _send<T>(Future<Response<T>> Function() request) {
    return _attempt(request, allowRetry: true);
  }

  Future<Response<T>> _attempt<T>(
    Future<Response<T>> Function() request, {
    required bool allowRetry,
  }) async {
    try {
      return await request();
    } on DioException catch (dioError) {
      final wrapped = dioError.error;
      if (wrapped is AppException) throw wrapped;
      // Mobile Chrome often drops the first cross-origin call (a status-0
      // "Load failed") and accepts the next one. Only idempotent calls are
      // retried, so a lost response cannot create a second record.
      if (allowRetry && shouldRetryTransportFailure(dioError)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        return _attempt(request, allowRetry: false);
      }
      final response = dioError.response;
      if (response == null) {
        throw NetworkException(
          'No connection. Try again when you are back online.',
          dioError,
        );
      }
      final body = response.data;
      final apiError = body is Map ? body['error'] : null;
      final code = apiError is Map ? apiError['code'] : null;
      final message = apiError is Map && apiError['message'] is String
          ? apiError['message'] as String
          : null;
      throw switch (response.statusCode) {
        401 => UnauthenticatedException(message ?? 'Sign in to continue.'),
        404 => NotFoundException(message ?? 'That record no longer exists.'),
        409 => UnexpectedException(
          message ?? 'That record changed. Refresh and try again.',
          dioError,
        ),
        413 => const MalformedDataException(
          'That image is larger than the 10 MB limit.',
        ),
        415 => const MalformedDataException('Only images can be uploaded.'),
        429 => RateLimitedException(
          message ?? 'Too many requests just now. Try again shortly.',
        ),
        _ when code == 'validation_error' => MalformedDataException(
          message ?? 'That request is not valid.',
        ),
        _ => UnexpectedException(message ?? 'Something went wrong.', dioError),
      };
    }
  }

  Map<String, dynamic> _object(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return const {};
  }
}
