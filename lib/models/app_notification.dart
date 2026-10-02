import 'json.dart';

class AppNotification {
  const AppNotification({
    required this.publicId,
    required this.type,
    required this.title,
    required this.message,
    this.data = const {},
    this.isRead = false,
    this.createdAt,
  });

  final String publicId;
  final String type;
  final String title;
  final String message;

  /// Deep-link ids stored by the backend trigger (trip_id, student_id, ...).
  final Map<String, String> data;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        publicId: publicId,
        type: type,
        title: title,
        message: message,
        data: data,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        publicId: asString(json['public_id']) ?? '',
        type: asString(json['notification_type']) ?? '',
        title: asString(json['title']) ?? '',
        message: asString(json['message']) ?? '',
        data: asMap(json['data']).map((k, v) => MapEntry(k, v?.toString() ?? '')),
        isRead: json['is_read'] == true,
        createdAt: asDate(json['created_at']),
      );
}
