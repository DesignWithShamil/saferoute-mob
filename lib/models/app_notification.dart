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
    this.schoolName,
    this.schoolCode,
    this.studentName,
    this.studentPublicId,
    this.isEdited = false,
  });

  final String publicId;
  final String type;
  final String title;
  final String message;

  /// Deep-link ids stored by the backend trigger (trip_id, student_id, ...).
  final Map<String, String> data;
  final bool isRead;
  final DateTime? createdAt;
  final String? schoolName;
  final String? schoolCode;
  final String? studentName;
  final String? studentPublicId;
  final bool isEdited;

  AppNotification copyWith({
    bool? isRead,
    String? title,
    String? message,
    bool? isEdited,
  }) =>
      AppNotification(
        publicId: publicId,
        type: type,
        title: title ?? this.title,
        message: message ?? this.message,
        data: data,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        schoolName: schoolName,
        schoolCode: schoolCode,
        studentName: studentName,
        studentPublicId: studentPublicId,
        isEdited: isEdited ?? this.isEdited,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final schoolMap = asMap(json['school']);
    final studentMap = asMap(json['student']);
    final dataMap = asMap(json['data']).map((k, v) => MapEntry(k, v?.toString() ?? ''));

    final schoolName = asString(schoolMap['name']) ?? dataMap['school_name'];
    final schoolCode = asString(schoolMap['code']);
    final studentName = asString(studentMap['full_name']) ?? dataMap['student_name'];
    final studentPublicId = asString(studentMap['public_id']) ?? dataMap['student_id'];
    final isEdited = json['is_edited'] == true ||
        dataMap['is_edited'] == 'true' ||
        dataMap['is_edited'] == '1';

    return AppNotification(
      publicId: asString(json['public_id']) ?? '',
      type: asString(json['notification_type']) ?? '',
      title: asString(json['title']) ?? '',
      message: asString(json['message']) ?? '',
      data: dataMap,
      isRead: json['is_read'] == true,
      createdAt: asDate(json['created_at']),
      schoolName: schoolName,
      schoolCode: schoolCode,
      studentName: studentName,
      studentPublicId: studentPublicId,
      isEdited: isEdited,
    );
  }
}
