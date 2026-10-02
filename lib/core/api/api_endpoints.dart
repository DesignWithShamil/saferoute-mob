/// Paths relative to [Env.apiBaseUrl]. All of these are existing Django
/// endpoints except [devices], which the mobile app added for FCM tokens.
class ApiEndpoints {
  ApiEndpoints._();

  static const login = '/auth/login/';
  static const registerParentRequestOtp = '/auth/register/parent/request-otp/';
  static const registerParent = '/auth/register/parent/';
  static const refresh = '/auth/refresh/';
  static const logout = '/auth/logout/';
  static const me = '/auth/me/';
  static const changePassword = '/auth/change-password/';
  static const passwordOtpRequest = '/auth/password-otp/request/';
  static const passwordOtpConfirm = '/auth/password-otp/confirm/';

  static const schools = '/schools/';
  static const schoolSettings = '/schools/settings/';

  static const routes = '/routes/';

  static const trips = '/trips/';
  static const tripToday = '/trips/today/';
  static const tripStart = '/trips/start/';
  static String tripAction(String tripId, String action) => '/trips/$tripId/$action/';

  static const gpsLocation = '/gps/location/';
  static const gpsParentLive = '/gps/parent-live/';
  static String busLocation(String busId) => '/gps/buses/$busId/location/';

  static const attendance = '/attendance/';
  static const attendanceRoster = '/attendance/roster/';
  static const attendanceManual = '/attendance/manual/';
  static const attendanceScan = '/attendance/scan/';
  static const attendanceVerifyDrop = '/attendance/verify-drop/';
  static const leaves = '/attendance/leaves/';
  static String leave(String id) => '/attendance/leaves/$id/';

  static const students = '/students/';
  static const studentLookup = '/students/lookup/';

  static const parentChildren = '/parent/children/';
  static const parentChildLink = '/parent/children/link/';
  static String parentChild(String studentId) => '/parent/children/$studentId/';
  static String parentChildUnlink(String studentId) => '/parent/children/$studentId/unlink/';

  static const sos = '/emergency/sos/';

  static const notifications = '/notifications/';
  static const notificationsUnreadCount = '/notifications/unread-count/';
  static const notificationsReadAll = '/notifications/read-all/';
  static String notificationRead(String id) => '/notifications/$id/read/';
  static String notification(String id) => '/notifications/$id/';
  static const notificationsClearAll = '/notifications/clear-all/';
  static const devices = '/notifications/devices/';
  static const notificationPreferences = '/notifications/preferences/';

  static const messagingConversations = '/messaging/conversations/';
  static const messagingConversationsEnsure = '/messaging/conversations/ensure/';
  static const messagingUnreadCount = '/messaging/conversations/unread-count/';
  static String messagingConversationMessages(String id) => '/messaging/conversations/$id/messages/';
  static String messagingConversationClearInbox(String id) => '/messaging/conversations/$id/clear-inbox/';
}
