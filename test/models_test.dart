import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saferoute/core/api/api_exception.dart';
import 'package:saferoute/core/utils/geo.dart';
import 'package:saferoute/models/parent_live.dart';
import 'package:saferoute/models/student.dart';
import 'package:saferoute/models/trip.dart';
import 'package:saferoute/models/user.dart';
import 'package:saferoute/screens/parent/parent_widgets.dart';
import 'package:saferoute/widgets/trip_map.dart';

void main() {
  group('Trip.fromJson', () {
    final json = {
      'public_id': 't1',
      'trip_type': 'AFTERNOON',
      'status': 'IN_PROGRESS',
      'route': {'public_id': 'r1', 'name': 'North', 'route_type': 'BOTH'},
      'bus': {'public_id': 'b1', 'bus_number': 'KA-01'},
      'current_stop': {'public_id': 's2', 'name': 'Market', 'sequence': 2, 'latitude': '12.900000', 'longitude': '77.500000'},
      'trip_stops': [
        {'public_id': 'ts2', 'sequence': 2, 'status': 'PENDING', 'stop': {'public_id': 's2', 'name': 'Market', 'sequence': 2}},
        {'public_id': 'ts1', 'sequence': 1, 'status': 'DEPARTED', 'stop': {'public_id': 's3', 'name': 'School', 'sequence': 3}},
      ],
    };

    test('keeps backend sequence order (afternoon reversal is server-side)', () {
      final trip = Trip.fromJson(json);
      expect(trip.tripStops.map((t) => t.sequence), [1, 2]);
      expect(trip.tripStops.first.stop!.name, 'School');
    });

    test('status helpers and current stop', () {
      final trip = Trip.fromJson(json);
      expect(trip.isActive, isTrue);
      expect(trip.isAfternoon, isTrue);
      expect(trip.currentTripStop!.publicId, 'ts2');
      expect(trip.currentStop!.latitude, 12.9);
      expect(TripType.label(trip.tripType), 'Evening');
    });

    test('list-endpoint shape (no trip_stops, current_stop as id) parses', () {
      final listRow = {
        'public_id': 't2',
        'trip_type': 'MORNING',
        'status': 'COMPLETED',
        'route': {'public_id': 'r1', 'name': 'North'},
        'current_stop': null,
        'ended_at': '2026-09-30T07:10:21Z',
      };
      final trip = Trip.fromJson(listRow);
      expect(trip.routeId, 'r1');
      expect(trip.tripStops, isEmpty);
      expect(trip.isFinished, isTrue);
      expect(Trip.fromJson({...listRow, 'current_stop': 42}).currentStop, isNull);
    });

    test('completed and cancelled are finished, not active', () {
      for (final s in ['COMPLETED', 'CANCELLED']) {
        final t = Trip.fromJson({...json, 'status': s});
        expect(t.isFinished, isTrue);
        expect(t.isActive, isFalse);
      }
    });
  });

  group('ParentLiveTrip', () {
    final json = {
      'child': {'public_id': 'c1', 'name': 'Asha', 'status': 'BOARDED', 'stop_id': 's3'},
      'trip': {
        'public_id': 't1',
        'status': 'IN_PROGRESS',
        'bus_number': 'KA-01',
        'route_name': 'North',
        'current_stop': 'Market',
        'stops': [
          {'public_id': 's1', 'sequence': 1, 'status': 'DEPARTED', 'name': 'Depot'},
          {'public_id': 's2', 'sequence': 2, 'status': 'ARRIVED', 'name': 'Market'},
          {'public_id': 's3', 'sequence': 3, 'status': 'PENDING', 'name': 'Park'},
        ],
      },
      'location': {'latitude': 12.9, 'longitude': 77.5, 'recorded_at': DateTime.now().toUtc().toIso8601String()},
    };

    test('next stop is the first not yet departed (matches Trip.current_stop)', () {
      final live = ParentLiveTrip.fromJson(json);
      expect(live.nextStop!.name, 'Market');
      expect(live.nextStop!.name, live.currentStopName);
      expect(live.childStop!.name, 'Park');
      expect(live.location!.isStale, isFalse);
    });

    test('no location means no fake position', () {
      final live = ParentLiveTrip.fromJson({...json, 'location': null});
      expect(live.location, isNull);
    });
  });

  group('ApiException.fromDio', () {
    DioException withResponse(int status, Map<String, dynamic> body) {
      final req = RequestOptions(path: '/x');
      return DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: status, data: body),
      );
    }

    test('uses backend message', () {
      final e = ApiException.fromDio(withResponse(409, {'success': false, 'message': 'No active trip', 'errors': {}}));
      expect(e.kind, ApiErrorKind.conflict);
      expect(e.message, 'No active trip');
    });

    test('maps timeouts and 5xx', () {
      final req = RequestOptions(path: '/x');
      expect(ApiException.fromDio(DioException(requestOptions: req, type: DioExceptionType.connectionTimeout)).kind,
          ApiErrorKind.timeout);
      expect(ApiException.fromDio(withResponse(502, {})).kind, ApiErrorKind.server);
    });
  });

  test('distance formula matches web utils/distance.js', () {
    final m = haversineMeters(12.9716, 77.5946, 12.9352, 77.6245);
    expect(m, closeTo(5140, 60));
    expect(formatDistance(850), '850 m');
    expect(formatDistance(5140), '5.1 km');
  });

  group('map places', () {
    test('school marker only when the API has coordinates', () {
      final withPos = School.fromJson({'public_id': 'sc', 'name': 'DPS', 'latitude': '12.97', 'longitude': '77.59'});
      expect(schoolPlace(withPos)!.position.latitude, 12.97);
      expect(schoolPlace(School.fromJson({'public_id': 'sc', 'name': 'DPS', 'latitude': null})), isNull);
    });

    Student student({String dropId = 'd1'}) => Student.fromJson({
          'public_id': 'st1',
          'full_name': 'Asha',
          'pickup_stop': {'public_id': 'p1', 'name': 'Gate', 'latitude': '12.1', 'longitude': '77.1', 'pickup_time': '07:30:00'},
          'drop_stop': {'public_id': dropId, 'name': 'Park', 'latitude': '12.2', 'longitude': '77.2', 'drop_time': '15:30:00'},
        });

    test('pickup and drop markers, skipping stops already on the trip', () {
      expect(childStopPlaces(student()).map((p) => p.kind), [MapPlaceKind.pickup, MapPlaceKind.drop]);
      expect(childStopPlaces(student(), skipStopIds: {'p1'}).map((p) => p.kind), [MapPlaceKind.drop]);
    });

    test('same stop for pickup and drop becomes one marker', () {
      final places = childStopPlaces(student(dropId: 'p1'));
      expect(places, hasLength(1));
      expect(places.single.details, contains('Asha\'s pickup and drop point'));
    });
  });

  group('parent children (/api/parent/children/)', () {
    Map<String, dynamic> child({required String name, required String school, Object? contacts}) => {
          'public_id': 'link-$name',
          'relation': 'MOTHER',
          'can_apply_leave': false,
          'linked_by': 'PARENT',
          'student': {
            'public_id': 'stu-$name',
            'full_name': name,
            'class_name': '5',
            'section': 'A',
            'pickup_bus': {'public_id': 'b1', 'bus_number': 'BUS-01'},
          },
          'school': {'public_id': 'sch-$school', 'name': school, 'latitude': '12.97', 'longitude': '77.59'},
          'pickup_route': {'public_id': 'r1', 'name': 'Route A', 'route_type': 'MORNING'},
          'drop_route': null,
          'transport_contacts': contacts,
        };

    test('each child carries its own school, routes and label', () {
      final rahul = ParentLink.fromJson(child(name: 'Rahul', school: 'ABC School'));
      final meera = ParentLink.fromJson(child(name: 'Meera', school: 'XYZ School'));
      expect(rahul.label, 'Rahul - ABC School');
      expect(meera.label, 'Meera - XYZ School');
      expect(meera.school.hasPosition, isTrue);
      expect(rahul.pickupRoute!.name, 'Route A');
      expect(rahul.dropRoute, isNull);
      expect(rahul.canApplyLeave, isFalse);
      expect(rahul.student.classLabel, '5-A');
      expect(rahul.contacts, isEmpty);
    });

    test('transport contacts only when the school shares them', () {
      final link = ParentLink.fromJson(child(name: 'Rahul', school: 'ABC School', contacts: {
        'pickup_driver': {'full_name': 'Ravi', 'phone': '99'},
        'pickup_helper': null,
        'drop_driver': {'full_name': 'Ravi', 'phone': '99'},
        'drop_helper': null,
      }));
      expect(link.contacts.map((c) => c.label), ['Morning driver', 'Evening driver']);
    });

    test('route map payload includes ordered stops', () {
      final route = ChildRoute.fromJsonOrNull({
        'public_id': 'r1',
        'name': 'Route A',
        'route_type': 'MORNING',
        'stops': [
          {'public_id': 's2', 'name': 'Park', 'sequence': 2, 'latitude': '12.9', 'longitude': '77.5'},
          {'public_id': 's1', 'name': 'Depot', 'sequence': 1, 'latitude': '12.8', 'longitude': '77.4'},
        ],
      })!;
      expect(route.stops.map((s) => s.name).toList(), ['Depot', 'Park']);
      expect(route.stops.first.hasPosition, isTrue);
    });

    test('link preview', () {
      final p = ChildLinkPreview.fromJson({
        'student': {'full_name': 'Meera', 'admission_number': 'B-100', 'class_name': '3', 'section': ''},
        'school': {'name': 'XYZ School', 'code': 'xyz'},
        'already_linked': true,
      });
      expect(p.fullName, 'Meera');
      expect(p.classLabel, '3');
      expect(p.schoolName, 'XYZ School');
      expect(p.alreadyLinked, isTrue);
    });

    test('parent-live carries the child\'s school and trip type', () {
      final live = ParentLiveTrip.fromJson({
        'child': {'public_id': 'stu-Meera', 'name': 'Meera', 'status': 'BOARDED', 'school': {'public_id': 's', 'name': 'XYZ School'}},
        'trip': {'public_id': 't', 'status': 'IN_PROGRESS', 'trip_type': 'MORNING', 'bus_number': 'BUS-B7', 'stops': []},
      });
      expect(live.schoolName, 'XYZ School');
      expect(live.tripType, 'MORNING');
    });
  });
}
