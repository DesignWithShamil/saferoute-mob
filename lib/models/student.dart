import 'json.dart';
import 'transport.dart';
import 'user.dart';

/// StudentMiniSerializer.
class PrimaryParentContact {
  const PrimaryParentContact({this.fullName = '', this.phone = '', this.email = ''});
  final String fullName;
  final String phone;
  final String email;

  static PrimaryParentContact? fromJsonOrNull(Object? json) {
    if (json is! Map) return null;
    final m = asMap(json);
    return PrimaryParentContact(
      fullName: asString(m['full_name']) ?? '',
      phone: asString(m['phone']) ?? '',
      email: asString(m['email']) ?? '',
    );
  }
}

class Student {
  const Student({
    required this.publicId,
    required this.fullName,
    this.admissionNumber = '',
    this.className = '',
    this.section = '',
    this.status = '',
    this.photo,
    this.pickupStop,
    this.dropStop,
    this.pickupBus,
    this.dropBus,
    this.requiresDropVerification = false,
    this.bloodGroup,
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.ageYears,
    this.primaryParent,
  });

  final String publicId;
  final String fullName;
  final String admissionNumber;
  final String className;
  final String section;
  final String status;
  final String? photo;
  final StopRef? pickupStop;
  final StopRef? dropStop;
  final BusRef? pickupBus;
  final BusRef? dropBus;
  final bool requiresDropVerification;
  final String? bloodGroup;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final int? ageYears;
  final PrimaryParentContact? primaryParent;

  String get classLabel => section.isEmpty ? className : '$className-$section';

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        publicId: asString(json['public_id']) ?? '',
        fullName: asString(json['full_name']) ?? '',
        admissionNumber: asString(json['admission_number']) ?? '',
        className: asString(json['class_name']) ?? '',
        section: asString(json['section']) ?? '',
        status: asString(json['status']) ?? '',
        photo: asString(json['photo']),
        pickupStop: StopRef.fromJsonOrNull(json['pickup_stop']),
        dropStop: StopRef.fromJsonOrNull(json['drop_stop']),
        pickupBus: BusRef.fromJsonOrNull(json['pickup_bus']),
        dropBus: BusRef.fromJsonOrNull(json['drop_bus']),
        requiresDropVerification: json['requires_drop_verification'] == true,
        bloodGroup: asString(json['blood_group']),
        emergencyContactName: asString(json['emergency_contact_name']) ?? '',
        emergencyContactPhone: asString(json['emergency_contact_phone']) ?? '',
        ageYears: json['age_years'] is int ? json['age_years'] as int : int.tryParse('${json['age_years']}'),
        primaryParent: PrimaryParentContact.fromJsonOrNull(json['primary_parent']),
      );
}

/// A route summary nested in `/api/parent/children/` (pickup_route / drop_route).
class ChildRoute {
  const ChildRoute({required this.publicId, required this.name, this.routeType = '', this.stops = const []});

  final String publicId;
  final String name;
  final String routeType;
  final List<StopRef> stops;

  static ChildRoute? fromJsonOrNull(Object? json) {
    if (json is! Map) return null;
    final m = asMap(json);
    return ChildRoute(
      publicId: asString(m['public_id']) ?? '',
      name: asString(m['name']) ?? '',
      routeType: asString(m['route_type']) ?? '',
      stops: asList(m['stops'], StopRef.fromJson)..sort((a, b) => a.sequence.compareTo(b.sequence)),
    );
  }
}

class TransportContact {
  const TransportContact({required this.label, required this.fullName, this.phone = ''});
  final String label;
  final String fullName;
  final String phone;
}

/// One of the parent's children, from `/api/parent/children/`. Everything
/// here belongs to the child's own school, which may differ between children.
class ParentLink {
  const ParentLink({
    required this.publicId,
    required this.student,
    required this.school,
    this.relation = '',
    this.canApplyLeave = true,
    this.linkedBy = '',
    this.pickupRoute,
    this.dropRoute,
    this.contacts = const [],
  });

  final String publicId;
  final Student student;
  final School school;
  final String relation;
  final bool canApplyLeave;
  final String linkedBy;
  final ChildRoute? pickupRoute;
  final ChildRoute? dropRoute;

  /// Only present when the child's school allows parents to contact the crew.
  final List<TransportContact> contacts;

  /// Child's display name in pickers (school is shown separately when needed).
  String get label => student.fullName;

  factory ParentLink.fromJson(Map<String, dynamic> json) {
    final contacts = asMap(json['transport_contacts']);
    TransportContact? person(String key, String label) {
      final p = contacts[key];
      if (p is! Map) return null;
      final m = asMap(p);
      return TransportContact(label: label, fullName: asString(m['full_name']) ?? '', phone: asString(m['phone']) ?? '');
    }

    return ParentLink(
      publicId: asString(json['public_id']) ?? '',
      student: Student.fromJson(asMap(json['student'])),
      school: School.fromJson(asMap(json['school'])),
      relation: asString(json['relation']) ?? '',
      canApplyLeave: json['can_apply_leave'] != false,
      linkedBy: asString(json['linked_by']) ?? '',
      pickupRoute: ChildRoute.fromJsonOrNull(json['pickup_route']),
      dropRoute: ChildRoute.fromJsonOrNull(json['drop_route']),
      contacts: [
        ?person('pickup_driver', 'Morning driver'),
        ?person('pickup_helper', 'Morning helper'),
        ?person('drop_driver', 'Evening driver'),
        ?person('drop_helper', 'Evening helper'),
      ],
    );
  }
}

/// What `/api/parent/children/link/` found for the entered details, shown to
/// the parent to confirm before the link is created.
class ChildLinkPreview {
  const ChildLinkPreview({
    required this.fullName,
    required this.schoolName,
    this.admissionNumber = '',
    this.className = '',
    this.section = '',
    this.alreadyLinked = false,
  });

  final String fullName;
  final String schoolName;
  final String admissionNumber;
  final String className;
  final String section;
  final bool alreadyLinked;

  String get classLabel => section.isEmpty ? className : '$className-$section';

  factory ChildLinkPreview.fromJson(Map<String, dynamic> json) {
    final student = asMap(json['student']);
    return ChildLinkPreview(
      fullName: asString(student['full_name']) ?? '',
      admissionNumber: asString(student['admission_number']) ?? '',
      className: asString(student['class_name']) ?? '',
      section: asString(student['section']) ?? '',
      schoolName: asString(asMap(json['school'])['name']) ?? '',
      alreadyLinked: json['already_linked'] == true,
    );
  }
}

/// Attendance.status values (apps/attendance/models.py).
class AttendanceStatus {
  AttendanceStatus._();
  static const notMarked = 'NOT_MARKED';
  static const boarded = 'BOARDED';
  static const absent = 'ABSENT';
  static const onLeave = 'ON_LEAVE';
  static const dropped = 'DROPPED';
  static const dropVerified = 'DROP_VERIFIED';

  static String label(String status) => switch (status) {
        notMarked => 'Not marked',
        boarded => 'Boarded',
        absent => 'Absent',
        onLeave => 'On leave',
        dropped => 'Dropped',
        dropVerified => 'Drop verified',
        _ => status,
      };
}

/// AttendanceSerializer.
class AttendanceRecord {
  const AttendanceRecord({
    required this.publicId,
    required this.student,
    required this.status,
    this.stop,
    this.droppedAtStop,
    this.method,
    this.markedBy,
    this.boardedAt,
    this.droppedAt,
    this.createdAt,
    this.tripType,
    this.tripDate,
    this.busNumber,
  });

  final String publicId;
  final Student student;
  final StopRef? stop;
  final StopRef? droppedAtStop;
  final String status;
  final String? method;
  final String? markedBy;
  final DateTime? boardedAt;
  final DateTime? droppedAt;
  final DateTime? createdAt;
  final String? tripType;
  final String? tripDate;
  final String? busNumber;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        publicId: asString(json['public_id']) ?? '',
        student: Student.fromJson(asMap(json['student'])),
        stop: StopRef.fromJsonOrNull(json['stop']),
        droppedAtStop: StopRef.fromJsonOrNull(json['dropped_at_stop']),
        status: asString(json['status']) ?? AttendanceStatus.notMarked,
        method: asString(json['method']),
        markedBy: asString(asMap(json['marked_by'])['full_name']),
        boardedAt: asDate(json['boarded_at']),
        droppedAt: asDate(json['dropped_at']),
        createdAt: asDate(json['created_at']),
        tripType: asString(json['trip_type']),
        tripDate: asString(json['trip_date']),
        busNumber: asString(json['bus_number']),
      );
}
