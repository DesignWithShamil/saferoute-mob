import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Thin wrapper over Dio that unwraps SafeRoute's standard
/// `{"success", "message", "data"}` envelope and turns every failure into an
/// [ApiException]. Repositories are the only callers.
class ApiClient {
  ApiClient({required TokenStorage storage, Future<void> Function()? onSessionExpired, String? baseUrl})
      : _dio = Dio(_options(baseUrl)) {
    _dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        dio: _dio,
        refreshDio: Dio(_options(baseUrl)),
        onSessionExpired: onSessionExpired,
      ),
    );
  }

  final Dio _dio;

  static BaseOptions _options(String? baseUrl) => BaseOptions(
        baseUrl: baseUrl ?? Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 15),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      );

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data}) => _send(() => _dio.post(path, data: data ?? const {}));

  Future<dynamic> patch(String path, {Object? data}) => _send(() => _dio.patch(path, data: data ?? const {}));

  Future<dynamic> put(String path, {Object? data}) => _send(() => _dio.put(path, data: data ?? const {}));

  Future<dynamic> delete(String path, {Object? data}) => _send(() => _dio.delete(path, data: data));

  /// Returns `data.results` of a paginated list response.
  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query}) async {
    final data = await get(path, query: query);
    if (data is Map && data['results'] is List) return data['results'] as List;
    if (data is List) return data;
    return const [];
  }

  /// Full response body (envelope included), for callers that need `message`.
  Future<Map<String, dynamic>> postRaw(String path, {Object? data}) async {
    try {
      final res = await _dio.post(path, data: data ?? const {});
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final res = await request();
      final body = res.data;
      if (body is Map && body.containsKey('data')) return body['data'];
      return body;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
