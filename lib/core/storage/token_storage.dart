import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWTs live only in the platform keystore/keychain, never in plain prefs.
/// Shared by the UI isolate and the GPS background-service isolate.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'saferoute_access_token';
  static const _refreshKey = 'saferoute_refresh_token';
  static const _fcmTokenKey = 'saferoute_fcm_token';
  static const _notificationPromptKey = 'saferoute_notification_prompted';
  static const _selectedChildKey = 'saferoute_selected_child';

  final FlutterSecureStorage _storage;

  Future<String?> get accessToken => _storage.read(key: _accessKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshKey);

  Future<void> saveTokens({required String access, String? refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    if (refresh != null) await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<String?> get registeredFcmToken => _storage.read(key: _fcmTokenKey);
  Future<void> setRegisteredFcmToken(String? token) =>
      token == null ? _storage.delete(key: _fcmTokenKey) : _storage.write(key: _fcmTokenKey, value: token);

  /// UI preference only (which child the parent screens show); access is always checked server-side.
  Future<String?> get selectedChildId => _storage.read(key: _selectedChildKey);
  Future<void> setSelectedChildId(String? id) =>
      id == null ? _storage.delete(key: _selectedChildKey) : _storage.write(key: _selectedChildKey, value: id);

  Future<bool> get notificationPromptShown async => (await _storage.read(key: _notificationPromptKey)) == '1';
  Future<void> markNotificationPromptShown() => _storage.write(key: _notificationPromptKey, value: '1');
}
