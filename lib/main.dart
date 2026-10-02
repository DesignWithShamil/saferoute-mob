import 'package:flutter/material.dart';

import 'app.dart';
import 'app_services.dart';
import 'core/location/gps_tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = AppServices.create();
  await services.notificationService.init();
  await GpsTrackingService.configure();
  runApp(SafeRouteApp(services: services));
}
