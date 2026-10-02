import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Build-time configuration, supplied with
/// `flutter run --dart-define-from-file=env/dev.json`.
///
/// Only public, non-secret values belong here. Firebase *client* options are
/// public by design; server credentials stay on the Django server.
class Env {
  Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static const osrmBaseUrl = String.fromEnvironment(
    'OSRM_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static const mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const _firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _firebaseSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _firebaseIosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static String get _platformAppId =>
      defaultTargetPlatform == TargetPlatform.iOS ? _firebaseIosAppId : _firebaseAndroidAppId;

  static bool get firebaseConfigured =>
      _firebaseApiKey.isNotEmpty &&
      _firebaseProjectId.isNotEmpty &&
      _firebaseSenderId.isNotEmpty &&
      _platformAppId.isNotEmpty;

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: _firebaseApiKey,
        appId: _platformAppId,
        messagingSenderId: _firebaseSenderId,
        projectId: _firebaseProjectId,
        storageBucket: _firebaseStorageBucket.isEmpty ? null : _firebaseStorageBucket,
        iosBundleId: _firebaseIosBundleId.isEmpty ? null : _firebaseIosBundleId,
      );

  /// WebSocket/host root derived from the API base, e.g. `http://host:8000`.
  static String get serverRoot => apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
}
