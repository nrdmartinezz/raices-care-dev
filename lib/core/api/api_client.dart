import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../errors/app_exception.dart';
import 'api_config.dart';

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
    final response = await _send(() => _dio.get<dynamic>(path, queryParameters: query));
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
          headers: {
            'Idempotency-Key': ?idempotencyKey,
            'If-Match': ?ifMatch,
          },
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

  Future<Response<T>> _send<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (dioError) {
      final wrapped = dioError.error;
      if (wrapped is AppException) throw wrapped;
      final response = dioError.response;
      if (response == null) {
        throw NetworkException(
          'No connection. Changes will sync when you are back online.',
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
        _ => UnexpectedException(
          message ?? 'Something went wrong.',
          dioError,
        ),
      };
    }
  }

  Map<String, dynamic> _object(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return const {};
  }
}
