import 'package:flutter_test/flutter_test.dart';
import 'package:saferoute/core/config/env.dart';
import 'package:saferoute/core/notifications/notification_channels.dart';
import 'package:saferoute/models/app_notification.dart';

void main() {
  group('FCM Configuration & Notification Tests', () {
    test('Env.firebaseConfigured is true by default', () {
      expect(Env.firebaseConfigured, isTrue);
      expect(Env.firebaseOptions.projectId, equals('saferoutez'));
      expect(Env.firebaseOptions.messagingSenderId, equals('1027827882337'));
      expect(Env.firebaseOptions.apiKey, equals('AIzaSyAJODJKNttg56-qBvcMAQTpSFusTIMgnd8'));
      expect(Env.firebaseOptions.appId, isNotEmpty);
      expect(Env.firebaseOptions.storageBucket, equals('saferoutez.firebasestorage.app'));
    });

    test('Android notification channel matches backend ANDROID_CHANNEL_ID', () {
      // Backend apps/notifications/push.py defines ANDROID_CHANNEL_ID = "saferoute_alerts"
      expect(NotificationChannels.alertsId, equals('saferoute_alerts'));
    });

    test('AppNotification.fromJson correctly parses school, student, and isEdited', () {
      final json = {
        'public_id': 'notif-123-abc',
        'notification_type': 'STAFF_MESSAGE',
        'title': 'School Announcement',
        'message': 'Classes will be closed tomorrow',
        'school': {
          'public_id': 'school-uuid-456',
          'name': 'Global Public School, Ottapalam',
          'code': 'GPSO',
        },
        'student': {
          'public_id': 'student-uuid-789',
          'full_name': 'Lakshmi Nair',
          'admission_number': 'ADM2026001',
        },
        'data': {
          'context': 'All parents',
          'is_edited': 'true',
        },
        'is_read': false,
        'created_at': '2026-10-22T10:00:00Z',
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.publicId, equals('notif-123-abc'));
      expect(notif.type, equals('STAFF_MESSAGE'));
      expect(notif.title, equals('School Announcement'));
      expect(notif.message, equals('Classes will be closed tomorrow'));
      expect(notif.schoolName, equals('Global Public School, Ottapalam'));
      expect(notif.schoolCode, equals('GPSO'));
      expect(notif.studentName, equals('Lakshmi Nair'));
      expect(notif.studentPublicId, equals('student-uuid-789'));
      expect(notif.isEdited, isTrue);
      expect(notif.isRead, isFalse);
    });

    test('AppNotification copyWith preserves school and student data', () {
      const original = AppNotification(
        publicId: 'id-1',
        type: 'BUS_NEAR_STOP',
        title: 'Bus Approaching',
        message: 'Bus is near Stop 2',
        schoolName: 'Global Public School',
        studentName: 'Lakshmi Nair',
        isEdited: false,
      );

      final updated = original.copyWith(isRead: true, isEdited: true);

      expect(updated.isRead, isTrue);
      expect(updated.isEdited, isTrue);
      expect(updated.schoolName, equals('Global Public School'));
      expect(updated.studentName, equals('Lakshmi Nair'));
      expect(updated.title, equals('Bus Approaching'));
    });
  });
}
