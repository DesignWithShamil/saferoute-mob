import 'package:dio/dio.dart';

enum ApiErrorKind { network, timeout, unauthorized, forbidden, notFound, conflict, validation, server, unknown }

/// A failed API call, already translated into something a user can read.
/// `message` prefers the backend's own `{"message": ...}` envelope text so the
/// mobile app shows the same business-rule errors as the web app.
class ApiException implements Exception {
  ApiException(this.kind, this.message, {this.statusCode, this.errors});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final Object? errors;

  bool get isRetryable => kind == ApiErrorKind.network || kind == ApiErrorKind.timeout || kind == ApiErrorKind.server;

  factory ApiException.fromDio(DioException e) {
    if (e.error is ApiException) return e.error! as ApiException;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(ApiErrorKind.timeout, 'The server took too long to respond. Please try again.');
      case DioExceptionType.connectionError:
        return ApiException(ApiErrorKind.network, 'No internet connection or the server is unreachable.');
      default:
        break;
    }

    final response = e.response;
    if (response == null) {
      return ApiException(ApiErrorKind.network, 'No internet connection or the server is unreachable.');
    }

    final status = response.statusCode ?? 0;
    final body = response.data;
    String? serverMessage;
    Object? errors;
    if (body is Map) {
      serverMessage = body['message']?.toString();
      errors = body['errors'];
      final detail = _firstFieldError(errors);
      if (serverMessage == 'Validation failed' && detail != null) serverMessage = detail;
    } else if (body is String && body.contains('DisallowedHost')) {
      serverMessage =
          'Server rejected this device (ALLOWED_HOSTS). Run Django on 0.0.0.0:8000 and set API_BASE_URL in env/dev.json to your PC IP.';
    }

    final kind = switch (status) {
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      400 || 422 => ApiErrorKind.validation,
      >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };

    final fallback = switch (kind) {
      ApiErrorKind.unauthorized => 'Your session has expired. Please sign in again.',
      ApiErrorKind.forbidden => 'You are not allowed to do that.',
      ApiErrorKind.notFound => 'Not found.',
      ApiErrorKind.server => 'Server error. Please try again shortly.',
      _ => 'Request failed.',
    };

    return ApiException(
      kind,
      (kind == ApiErrorKind.server || serverMessage == null || serverMessage.isEmpty) ? fallback : serverMessage,
      statusCode: status,
      errors: errors,
    );
  }

  static String? _firstFieldError(Object? errors) {
    if (errors is Map && errors.isNotEmpty) {
      final value = errors.values.first;
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String) return value;
    }
    return null;
  }

  @override
  String toString() => message;
}

/// Human-readable text for any error thrown out of a repository call.
String describeError(Object error) {
  if (error is ApiException) return error.message;
  if (error is DioException) return ApiException.fromDio(error).message;
  return 'Something went wrong. Please try again.';
}
