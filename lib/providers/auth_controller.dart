import 'package:flutter/foundation.dart';

import '../app_services.dart';
import '../core/api/api_exception.dart';
import '../models/user.dart';

enum AuthStatus { loading, signedOut, signedIn, unreachable }

class AuthController extends ChangeNotifier {
  AuthController(this._s) {
    _s.sessionExpired.addListener(_onSessionExpired);
  }

  final AppServices _s;

  AuthStatus status = AuthStatus.loading;
  AppUser? user;
  School? school;
  String? message;

  /// Called when the user signs out or the session expires, so role
  /// controllers can drop cached data and stop their timers.
  final List<VoidCallback> _signOutHooks = [];
  void addSignOutHook(VoidCallback hook) => _signOutHooks.add(hook);

  Future<void> bootstrap() async {
    status = AuthStatus.loading;
    message = null;
    notifyListeners();
    if (!await _s.auth.hasSession) {
      _setSignedOut();
      return;
    }
    try {
      await _loadProfile();
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized) {
        await _s.storage.clearTokens();
        _setSignedOut();
      } else {
        status = AuthStatus.unreachable;
        message = e.message;
        notifyListeners();
      }
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> requestParentRegisterOtp({
    required String fullName,
    required String email,
    required String phone,
  }) async {
    try {
      await _s.auth.requestParentRegisterOtp(fullName: fullName, email: email, phone: phone);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return describeError(e);
    }
  }

  Future<String?> registerParent({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String otp,
  }) async {
    try {
      await _s.auth.registerParent(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        otp: otp,
      );
      await _loadProfile();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return describeError(e);
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      await _s.auth.login(email, password);
      await _loadProfile();
      return null;
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.network || e.kind == ApiErrorKind.timeout) {
        return '${e.message} Check API_BASE_URL in env/dev.json (use your PC LAN IP on a physical phone, 10.0.2.2 on emulator).';
      }
      if (e.kind == ApiErrorKind.unauthorized || e.kind == ApiErrorKind.validation || e.kind == ApiErrorKind.unknown) {
        if (e.message.contains('ALLOWED_HOSTS') || e.message.contains('API_BASE_URL')) return e.message;
        return e.message == 'Request failed.' ? 'Invalid email or password' : e.message;
      }
      return e.message;
    } catch (e) {
      return describeError(e);
    }
  }

  Future<String?> updateProfile({required String fullName, String? phone}) async {
    try {
      user = await _s.auth.updateProfile(fullName: fullName, phone: phone);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return describeError(e);
    }
  }

  Future<String?> changePassword({
    String? oldPassword,
    String? otp,
    required String newPassword,
  }) async {
    try {
      await _s.auth.changePassword(oldPassword: oldPassword, otp: otp, newPassword: newPassword);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return describeError(e);
    }
  }

  Future<String?> requestPasswordOtp({required String purpose, String? email}) async {
    try {
      await _s.auth.requestPasswordOtp(purpose: purpose, email: email);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return describeError(e);
    }
  }

  Future<String?> confirmForgotPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _s.auth.confirmPasswordOtp(
        purpose: 'forgot_password',
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return describeError(e);
    }
  }

  Future<void> refreshProfile() async {
    try {
      await _loadProfile();
    } on ApiException catch (e) {
      message = e.message;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _s.gps.stop();
    await _s.notificationService.onSigningOut();
    await _s.auth.logout();
    _s.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    _setSignedOut();
  }

  Future<void> _loadProfile() async {
    final me = await _s.auth.me();
    user = me;
    school = null;
    status = AuthStatus.signedIn;
    _s.deepLinks.attachUser(me);
    notifyListeners();
    if (me.isSupportedOnMobile) {
      try {
        school = await _s.transport.mySchool();
        notifyListeners();
      } catch (_) {
        // School name is cosmetic; don't block sign-in on it.
      }
    }
  }

  void _onSessionExpired() {
    if (status != AuthStatus.signedIn) return;
    _s.gps.stop();
    message = 'Your session has expired. Please sign in again.';
    _setSignedOut(keepMessage: true);
  }

  void _setSignedOut({bool keepMessage = false}) {
    user = null;
    school = null;
    if (!keepMessage) message = null;
    status = AuthStatus.signedOut;
    _s.deepLinks.attachUser(null);
    for (final hook in _signOutHooks) {
      hook();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _s.sessionExpired.removeListener(_onSessionExpired);
    super.dispose();
  }
}
