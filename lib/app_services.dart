import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/firebase/notification_service.dart';
import 'core/location/gps_tracking_service.dart';
import 'core/location/location_service.dart';
import 'core/navigation/deep_link_router.dart';
import 'core/storage/token_storage.dart';
import 'repositories/attendance_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/messaging_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/transport_repository.dart';
import 'repositories/trip_repository.dart';
import 'services/route_geometry_service.dart';
import 'services/websocket_service.dart';

/// Composition root: one instance of each service, wired once in main().
class AppServices {
  AppServices._({
    required this.storage,
    required this.api,
    required this.auth,
    required this.trips,
    required this.attendance,
    required this.transport,
    required this.notifications,
    required this.messaging,
    required this.notificationService,
    required this.gps,
    required this.location,
    required this.geometry,
    required this.deepLinks,
    required this.navigatorKey,
    required this.messengerKey,
    required this.sessionExpired,
    required this.webSocket,
  });

  final TokenStorage storage;
  final ApiClient api;
  final AuthRepository auth;
  final TripRepository trips;
  final AttendanceRepository attendance;
  final TransportRepository transport;
  final NotificationRepository notifications;
  final MessagingRepository messaging;
  final NotificationService notificationService;
  final GpsTrackingService gps;
  final LocationService location;
  final RouteGeometryService geometry;
  final DeepLinkRouter deepLinks;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final WebSocketService webSocket;

  /// Fired by the API layer when the refresh token is rejected.
  final ValueNotifier<int> sessionExpired;

  factory AppServices.create() {
    final storage = TokenStorage();
    final sessionExpired = ValueNotifier<int>(0);
    final api = ApiClient(storage: storage, onSessionExpired: () async => sessionExpired.value++);
    final notifications = NotificationRepository(api);
    final messaging = MessagingRepository(api);
    final navigatorKey = GlobalKey<NavigatorState>();
    final webSocket = WebSocketService();
    return AppServices._(
      storage: storage,
      api: api,
      auth: AuthRepository(api, storage),
      trips: TripRepository(api),
      attendance: AttendanceRepository(api),
      transport: TransportRepository(api),
      notifications: notifications,
      messaging: messaging,
      notificationService: NotificationService(repository: notifications, storage: storage),
      gps: GpsTrackingService(),
      location: LocationService(),
      geometry: RouteGeometryService(),
      deepLinks: DeepLinkRouter(navigatorKey: navigatorKey, notifications: notifications),
      navigatorKey: navigatorKey,
      messengerKey: GlobalKey<ScaffoldMessengerState>(),
      sessionExpired: sessionExpired,
      webSocket: webSocket,
    );
  }
}
