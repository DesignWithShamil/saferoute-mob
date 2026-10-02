import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// Foreground (UI isolate) location helpers: permission flow with an
/// explanation shown first, and one-shot fixes for trip start/end.
class LocationService {
  Future<LocationAccess> currentAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
    return _map(await Geolocator.checkPermission());
  }

  /// Explains why location is needed, then asks. Returns the resulting access.
  Future<LocationAccess> ensureAccess(BuildContext context) async {
    var access = await currentAccess();
    if (access == LocationAccess.granted) return access;
    if (!context.mounted) return access;

    if (access == LocationAccess.serviceDisabled) {
      final open = await _explain(
        context,
        title: 'Turn on location',
        message: 'Your phone\'s location (GPS) is switched off. SafeRoute needs it to share the bus position '
            'with parents and the school during this trip.',
        action: 'Open settings',
      );
      if (open) await Geolocator.openLocationSettings();
      return currentAccess();
    }

    if (access == LocationAccess.deniedForever) {
      final open = await _explain(
        context,
        title: 'Location permission needed',
        message: 'Location permission was denied. Enable it for SafeRoute in app settings so the bus position '
            'can be shared during the trip.',
        action: 'Open app settings',
      );
      if (open) await Geolocator.openAppSettings();
      return currentAccess();
    }

    final proceed = await _explain(
      context,
      title: 'Share bus location',
      message: 'While a trip is active, SafeRoute uses your phone\'s GPS as the bus location so parents and the '
          'school can follow the bus. Tracking stops automatically when the trip ends. '
          'A notification stays visible while location is being shared.',
      action: 'Continue',
    );
    if (!proceed) return access;
    access = _map(await Geolocator.requestPermission());
    return access;
  }

  /// A single fix, or null if none is available within [timeout].
  Future<Position?> currentPosition({Duration timeout = const Duration(seconds: 12)}) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
      );
    } on LocationServiceDisabledException {
      // Fused provider settings check failed although location may be on; use the platform provider.
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(accuracy: LocationAccuracy.high, timeLimit: timeout, forceLocationManager: true),
        );
      } catch (_) {
        return Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  static LocationAccess _map(LocationPermission p) => switch (p) {
        LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        _ => LocationAccess.denied,
      };

  static Future<bool> _explain(BuildContext context,
      {required String title, required String message, required String action}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.my_location),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return result ?? false;
  }
}
