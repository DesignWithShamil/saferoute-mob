import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/api_endpoints.dart';
import '../core/storage/token_storage.dart';
import '../models/json.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  Future<bool> get hasSession async => (await _storage.accessToken) != null;

  Future<void> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final data = asMap(
      await _api.post(ApiEndpoints.login, data: {'email': normalizedEmail, 'password': password}),
    );
    final access = data['access'] as String?;
    if (access == null || access.isEmpty) {
      throw ApiException(ApiErrorKind.server, 'Unexpected login response from server.');
    }
    await _storage.saveTokens(access: access, refresh: data['refresh'] as String?);
  }

  Future<void> requestParentRegisterOtp({
    required String fullName,
    required String email,
    required String phone,
  }) async {
    await _api.post(ApiEndpoints.registerParentRequestOtp, data: {
      'full_name': fullName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
    });
  }

  Future<void> registerParent({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String otp,
  }) async {
    final data = asMap(await _api.post(ApiEndpoints.registerParent, data: {
      'full_name': fullName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
      'otp': otp.trim(),
    }));
    await _storage.saveTokens(access: data['access'] as String, refresh: data['refresh'] as String?);
  }

  Future<AppUser> me() async => AppUser.fromJson(asMap(await _api.get(ApiEndpoints.me)));

  Future<AppUser> updateProfile({required String fullName, String? phone}) async {
    final data = asMap(await _api.patch(ApiEndpoints.me, data: {
      'full_name': fullName.trim(),
      if (phone != null) 'phone': phone.trim(),
    }));
    return AppUser.fromJson(data);
  }

  Future<void> changePassword({
    String? oldPassword,
    String? otp,
    required String newPassword,
  }) async {
    final data = <String, dynamic>{'new_password': newPassword};
    if (otp != null && otp.trim().isNotEmpty) {
      data['otp'] = otp.trim();
    } else {
      data['old_password'] = oldPassword ?? '';
    }
    await _api.post(ApiEndpoints.changePassword, data: data);
  }

  Future<void> requestPasswordOtp({required String purpose, String? email}) async {
    await _api.post(ApiEndpoints.passwordOtpRequest, data: {
      'purpose': purpose,
      if (email != null) 'email': email.trim(),
    });
  }

  Future<void> confirmPasswordOtp({
    required String purpose,
    required String otp,
    required String newPassword,
    String? email,
  }) async {
    await _api.post(ApiEndpoints.passwordOtpConfirm, data: {
      'purpose': purpose,
      'otp': otp.trim(),
      'new_password': newPassword,
      if (email != null) 'email': email.trim(),
    });
  }

  /// Local tokens are cleared even if the server call fails, so logging out
  /// always works offline.
  Future<void> logout() async {
    final refresh = await _storage.refreshToken;
    try {
      if (refresh != null) await _api.post(ApiEndpoints.logout, data: {'refresh': refresh});
    } catch (_) {
      // Best-effort server-side invalidation.
    } finally {
      await _storage.clearTokens();
    }
  }
}
