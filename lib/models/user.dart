import 'json.dart';

class UserRole {
  UserRole._();

  static const driver = 'DRIVER';
  static const helper = 'HELPER';
  static const parent = 'PARENT';
  static const schoolAdmin = 'SCHOOL_ADMIN';
  static const superAdmin = 'SUPER_ADMIN';

  static const mobileRoles = {driver, helper, parent};

  static String label(String role) => switch (role) {
        driver => 'Driver',
        helper => 'Helper',
        parent => 'Parent',
        schoolAdmin => 'School Admin',
        superAdmin => 'Super Admin',
        _ => role,
      };
}

class SchoolSettings {
  const SchoolSettings({
    this.allowManualStopOverride = false,
    this.enableAutoDetect = true,
    this.gpsTrackingEnabled = true,
    this.gpsTrackingIntervalSeconds = 15,
    this.allowParentDriverContact = false,
  });

  final bool allowManualStopOverride;
  final bool enableAutoDetect;
  final bool gpsTrackingEnabled;
  final int gpsTrackingIntervalSeconds;
  final bool allowParentDriverContact;

  factory SchoolSettings.fromJson(Map<String, dynamic> json) => SchoolSettings(
        allowManualStopOverride: json['allow_manual_stop_override'] == true,
        enableAutoDetect: json['enable_auto_detect'] != false,
        gpsTrackingEnabled: json['gps_tracking_enabled'] != false,
        gpsTrackingIntervalSeconds: asInt(json['gps_tracking_interval_seconds']) ?? 15,
        allowParentDriverContact: json['allow_parent_driver_contact'] == true,
      );
}

class AppUser {
  const AppUser({
    required this.publicId,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone = '',
    this.schoolId,
    this.schoolSettings = const SchoolSettings(),
  });

  final String publicId;
  final String email;
  final String fullName;
  final String phone;
  final String role;
  final String? schoolId;
  final SchoolSettings schoolSettings;

  bool get isDriver => role == UserRole.driver;
  bool get isHelper => role == UserRole.helper;
  bool get isParent => role == UserRole.parent;
  bool get isSupportedOnMobile => UserRole.mobileRoles.contains(role);

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        publicId: asString(json['public_id']) ?? '',
        email: asString(json['email']) ?? '',
        fullName: asString(json['full_name']) ?? '',
        phone: asString(json['phone']) ?? '',
        role: asString(json['role']) ?? '',
        schoolId: asString(json['school']),
        schoolSettings: json['school_settings'] is Map
            ? SchoolSettings.fromJson(asMap(json['school_settings']))
            : const SchoolSettings(),
      );
}

class School {
  const School({
    required this.publicId,
    required this.name,
    this.contactPhone = '',
    this.address = '',
    this.latitude,
    this.longitude,
  });

  final String publicId;
  final String name;
  final String contactPhone;
  final String address;

  /// Optional on the backend (School.latitude/longitude are nullable).
  final double? latitude;
  final double? longitude;

  bool get hasPosition => latitude != null && longitude != null;

  factory School.fromJson(Map<String, dynamic> json) => School(
        publicId: asString(json['public_id']) ?? '',
        name: asString(json['name']) ?? '',
        contactPhone: asString(json['contact_phone']) ?? '',
        address: asString(json['address']) ?? '',
        latitude: asDouble(json['latitude']),
        longitude: asDouble(json['longitude']),
      );
}
