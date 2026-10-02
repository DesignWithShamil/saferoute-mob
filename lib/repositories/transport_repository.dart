import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/json.dart';
import '../models/leave.dart';
import '../models/parent_live.dart';
import '../models/student.dart';
import '../models/transport.dart';
import '../models/user.dart';

/// School, live-location, parent-link and SOS reads/writes.
class TransportRepository {
  TransportRepository(this._api);

  final ApiClient _api;

  /// `/api/schools/` is scoped to the caller's own school for non-super-admins.
  Future<School?> mySchool() async {
    final rows = await _api.getList(ApiEndpoints.schools);
    final first = rows.whereType<Map>().firstOrNull;
    return first == null ? null : School.fromJson(asMap(first));
  }

  Future<SchoolSettings> schoolSettings() async =>
      SchoolSettings.fromJson(asMap(await _api.get(ApiEndpoints.schoolSettings)));

  Future<BusLocation?> busLocation(String busId) async =>
      BusLocation.fromJsonOrNull(await _api.get(ApiEndpoints.busLocation(busId)));

  /// Active trips of the parent's children; [studentId] narrows it to one of them.
  Future<List<ParentLiveTrip>> parentLive({String? studentId}) async => asList(
        await _api.get(ApiEndpoints.gpsParentLive, query: studentId == null ? null : {'student': studentId}),
        ParentLiveTrip.fromJson,
      );

  /// Every child linked to the signed-in parent, across schools.
  Future<List<ParentLink>> myChildren() async => asList(await _api.get(ApiEndpoints.parentChildren), ParentLink.fromJson);

  Map<String, dynamic> _linkBody(String schoolCode, String studentNumber, String linkCode, String relation, bool confirm) => {
        'school_code': schoolCode.trim(),
        'student_number': studentNumber.trim(),
        'link_code': linkCode.trim(),
        'relation': relation,
        'confirm': confirm,
      };

  Future<ChildLinkPreview> previewChildLink(String schoolCode, String studentNumber, String linkCode, String relation) async =>
      ChildLinkPreview.fromJson(asMap(
        await _api.post(ApiEndpoints.parentChildLink, data: _linkBody(schoolCode, studentNumber, linkCode, relation, false)),
      ));

  Future<ParentLink> confirmChildLink(String schoolCode, String studentNumber, String linkCode, String relation) async =>
      ParentLink.fromJson(asMap(
        await _api.post(ApiEndpoints.parentChildLink, data: _linkBody(schoolCode, studentNumber, linkCode, relation, true)),
      ));

  Future<void> unlinkChild(String studentId) => _api.delete(ApiEndpoints.parentChildUnlink(studentId));

  /// Child detail with route stops for the parent's route map.
  Future<ParentLink> childDetail(String studentId) async =>
      ParentLink.fromJson(asMap(await _api.get(ApiEndpoints.parentChild(studentId))));

  Future<List<Student>> assignedStudents() async {
    final rows = await _api.getList(ApiEndpoints.students, query: {'page_size': 100});
    return rows.whereType<Map>().map((e) => Student.fromJson(asMap(e))).toList();
  }

  Future<StudentLookup?> lookupStudent(String query) async {
    final data = await _api.get(ApiEndpoints.studentLookup, query: {'q': query.trim()});
    if (data is! Map || data.isEmpty) return null;
    return StudentLookup.fromJson(asMap(data));
  }

  Future<void> raiseSos(String message) => _api.post(ApiEndpoints.sos, data: {'message': message});
}
