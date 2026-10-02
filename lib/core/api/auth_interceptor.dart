import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_endpoints.dart';

/// Attaches the access token and transparently refreshes it once on a 401,
/// mirroring the web app's axios interceptor. Being a [QueuedInterceptor],
/// concurrent 401s are handled one at a time, so only one refresh is issued.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.storage,
    required this.dio,
    required this.refreshDio,
    this.onSessionExpired,
  });

  final TokenStorage storage;
  final Dio dio;

  /// Separate instance without this interceptor, so refreshing can't recurse.
  final Dio refreshDio;
  final Future<void> Function()? onSessionExpired;

  static const _retriedKey = 'auth_retried';
  static const _tokenUsedKey = 'auth_token_used';

  bool _isAuthPath(String path) => path.endsWith(ApiEndpoints.login) || path.endsWith(ApiEndpoints.refresh);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isAuthPath(options.path)) {
      final token = await storage.accessToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        options.extra[_tokenUsedKey] = token;
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || _isAuthPath(options.path) || options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final current = await storage.accessToken;
    final usedToken = options.extra[_tokenUsedKey];
    String? freshToken;
    if (current != null && usedToken != null && current != usedToken) {
      freshToken = current; // Another queued request already refreshed it.
    } else {
      try {
        freshToken = await _refresh();
      } on DioException catch (refreshError) {
        return handler.next(refreshError);
      }
    }

    if (freshToken == null) {
      await storage.clearTokens();
      await onSessionExpired?.call();
      return handler.next(err);
    }

    options.extra[_retriedKey] = true;
    options.headers['Authorization'] = 'Bearer $freshToken';
    options.extra[_tokenUsedKey] = freshToken;
    try {
      handler.resolve(await dio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<String?> _refresh() async {
    final refresh = await storage.refreshToken;
    if (refresh == null) return null;
    try {
      final res = await refreshDio.post(ApiEndpoints.refresh, data: {'refresh': refresh});
      final access = (res.data as Map)['data']?['access'] as String?;
      if (access == null) return null;
      await storage.saveTokens(access: access);
      return access;
    } on DioException catch (e) {
      // Only a definitive rejection ends the session; a network blip must not log the user out.
      final status = e.response?.statusCode;
      if (status == 401 || status == 400) return null;
      rethrow;
    }
  }
}
