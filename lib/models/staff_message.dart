import 'json.dart';

class StaffMessagingUser {
  const StaffMessagingUser({
    required this.publicId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
  });

  final String publicId;
  final String fullName;
  final String email;
  final String phone;
  final String role;

  factory StaffMessagingUser.fromJson(Map<String, dynamic> json) => StaffMessagingUser(
        publicId: asString(json['public_id']) ?? '',
        fullName: asString(json['full_name']) ?? '',
        email: asString(json['email']) ?? '',
        phone: asString(json['phone']) ?? '',
        role: asString(json['role']) ?? '',
      );
}

class StaffMessage {
  const StaffMessage({
    required this.publicId,
    required this.body,
    required this.isMine,
    required this.createdAt,
    this.sender,
    this.readAt,
    this.targetType,
    this.context = const {},
  });

  final String publicId;
  final String body;
  final bool isMine;
  final DateTime? createdAt;
  final StaffMessagingUser? sender;
  final DateTime? readAt;
  final String? targetType;
  final Map<String, dynamic> context;

  static const _targetLabels = {
    'ALL_DRIVERS': 'All drivers',
    'ALL_HELPERS': 'All helpers',
    'BUS': 'Specific bus',
    'ROUTE': 'Specific route',
    'BUS_STAFF': 'Bus staff',
  };

  String? get contextLabel {
    final routeNames = context['route_names'];
    if (routeNames is List && routeNames.isNotEmpty) {
      final names = routeNames.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      if (names.length > 3) return '${names.take(3).join(', ')} +${names.length - 3} more';
      if (names.isNotEmpty) return names.join(', ');
    }
    final regs = context['registration_numbers'];
    if (regs is List && regs.isNotEmpty) {
      final plates = regs.map((e) => 'Plate ${e.toString()}').toList();
      if (plates.length > 3) return '${plates.take(3).join(', ')} +${plates.length - 3} more';
      if (plates.isNotEmpty) return plates.join(', ');
    }
    final busNums = context['bus_numbers'];
    if (busNums is List && busNums.isNotEmpty) {
      final nums = busNums.map((e) => 'Bus ${e.toString()}').toList();
      if (nums.length > 3) return '${nums.take(3).join(', ')} +${nums.length - 3} more';
      if (nums.isNotEmpty) return nums.join(', ');
    }
    final reg = asString(context['registration_number']);
    if (reg != null && reg.isNotEmpty) return 'Bus plate: $reg';
    final route = asString(context['route_name']);
    if (route != null && route.isNotEmpty) return 'Route: $route';
    final bus = asString(context['bus_number']);
    if (bus != null && bus.isNotEmpty) return 'Bus: $bus';
    return asString(context['target_label']);
  }

  String? get audienceLabel {
    final detail = contextLabel;
    final type = targetType != null && targetType!.isNotEmpty ? _targetLabels[targetType] ?? targetType : null;
    if (type != null && detail != null && detail.isNotEmpty) return '$type · $detail';
    if (detail != null && detail.isNotEmpty) return detail;
    return type;
  }

  factory StaffMessage.fromJson(Map<String, dynamic> json) => StaffMessage(
        publicId: asString(json['public_id']) ?? '',
        body: asString(json['body']) ?? '',
        isMine: json['is_mine'] == true,
        createdAt: asDate(json['created_at']),
        readAt: asDate(json['read_at']),
        targetType: asString(json['target_type']),
        context: json['context'] is Map ? Map<String, dynamic>.from(json['context'] as Map) : const {},
        sender: json['sender'] is Map ? StaffMessagingUser.fromJson(asMap(json['sender'])) : null,
      );
}

class StaffConversation {
  const StaffConversation({
    required this.publicId,
    required this.operator,
    this.unreadCount = 0,
    this.lastMessage,
    this.updatedAt,
  });

  final String publicId;
  final StaffMessagingUser operator;
  final int unreadCount;
  final StaffMessage? lastMessage;
  final DateTime? updatedAt;

  factory StaffConversation.fromJson(Map<String, dynamic> json) => StaffConversation(
        publicId: asString(json['public_id']) ?? '',
        operator: StaffMessagingUser.fromJson(asMap(json['operator'])),
        unreadCount: asInt(json['unread_count']) ?? 0,
        lastMessage: json['last_message'] is Map ? StaffMessage.fromJson(asMap(json['last_message'])) : null,
        updatedAt: asDate(json['updated_at']),
      );
}
