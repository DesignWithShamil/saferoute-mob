# SafeRoute Mobile — Audit & API Mapping

The Flutter app is a client of the existing Django API. Nothing below changes
existing endpoint behaviour; the only backend addition is device-token
registration + FCM delivery (section 4).

## 1. Audit findings that shape the mobile app

| Topic | Existing behaviour (source of truth) |
|---|---|
| Envelope | Every response is `{success, message, data}` / `{success:false, message, errors}`. Lists are paginated inside `data.results`. |
| Auth | SimpleJWT. `POST /api/auth/login/` → `data.{access, refresh, role, school, full_name}`. Access 15 min. `POST /api/auth/refresh/` returns only a new `access` (refresh token is not rotated by this view). |
| Roles | `SUPER_ADMIN`, `SCHOOL_ADMIN`, `DRIVER`, `HELPER`, `PARENT`. Mobile supports the last three; admins are told to use the web app. |
| IDs | All objects are addressed by UUID `public_id`. |
| Trip types | `MORNING` and `AFTERNOON`. The web labels `AFTERNOON` as "Evening Trip"; mobile does the same. There is no `EVENING` value. |
| Trip statuses | `STARTED` → `IN_PROGRESS` ↔ `PAUSED`, `EMERGENCY` → `COMPLETED` / `CANCELLED`. Active = `STARTED, IN_PROGRESS, PAUSED, EMERGENCY`. |
| Stop order | Computed by the server at trip start (`TripService.start_trip`): `BOTH` routes run afternoon stops in reverse sequence. Mobile only ever renders `trip.trip_stops` ordered by `sequence`. |
| Stop progress | `TripStop.status`: `PENDING → ARRIVED → DEPARTED`. Driven by server geofencing on each GPS point, or by `advance-stop` when `allow_manual_stop_override` is on. `trip.current_stop` is the next/current stop; `null` means all stops done → End Trip. |
| Attendance | Morning: `NOT_MARKED → BOARDED` (or `ABSENT`). Afternoon: board everyone at school while `STARTED` (required before `begin`), then `BOARDED → DROPPED` / `DROP_VERIFIED` (PIN). `end` is refused while anyone is still `BOARDED` or a PIN drop is unverified. |
| GPS | `POST /api/gps/location/` (driver only). Trip is derived server-side from the driver's own active trip; 409 when none. Throttle 120/min. |
| Route geometry | Backend stores only stop coordinates. The web draws roads with the public OSRM API (`mapProviderService.calculateRoute`) and falls back to straight lines. Mobile uses the identical approach — no backend change. |
| Tenant isolation | Every queryset is filtered from `request.user` (school / driver / helper / parent links). Mobile never sends a school/bus/trip id where the backend derives it. |

### Pre-existing backend defects found (not changed — reported)

1. `GET /api/trips/`, `/api/trips/today/`, `/api/trips/<id>/`, `/api/trips/<id>/location/` return **500 for PARENT** users: `_trip_queryset_for` filters on `trip_stops__stop__students__parentstudent__parent`, but `RouteStop` has no `students` relation (`FieldError`).
2. WebSocket `/ws/gps/<bus>/` fails for **PARENT** users: `GPSConsumer._is_authorized` uses `bus.students`, which does not exist on `Bus` (`AttributeError`).
3. `POST /api/auth/logout/` calls `RefreshToken.blacklist()` but `rest_framework_simplejwt.token_blacklist` is not in `INSTALLED_APPS`.

The web parent dashboard avoids 1 and 2 by polling `/api/gps/parent-live/`; the mobile parent flow does the same. Mobile logout clears local tokens even if the server call fails.

## 2. Feature → endpoint mapping

| Mobile feature | Endpoint | Method | Request | Response (`data`) | Screen |
|---|---|---|---|---|---|
| Login | `/auth/login/` | POST | `email, password` | `access, refresh, role, school, full_name` | Login |
| Current user | `/auth/me/` | GET | – | `public_id, email, full_name, phone, role, school, school_settings` | Splash / all homes |
| Refresh | `/auth/refresh/` | POST | `refresh` | `access` | (interceptor) |
| Logout | `/auth/logout/` | POST | `refresh` | – | Profile |
| School name | `/schools/` | GET | – | own school only (queryset-scoped) | Driver/Helper/Parent header |
| School settings | `/schools/settings/` | GET | – | `allow_manual_stop_override, enable_auto_detect, gps_tracking_enabled, …` | Driver/Helper trip |
| Assigned routes | `/routes/` | GET | – | routes assigned to driver/helper (with `bus`, `stops`, `route_type`) | Driver home |
| Today's trip | `/trips/today/` | GET | – | active trip, else today's latest, else `null` | Driver / Helper home |
| Start trip | `/trips/start/` | POST | `route_public_id, trip_type, latitude, longitude` | Trip (`STARTED`) | Driver home |
| Start driving | `/trips/<id>/begin/` | POST | – | Trip (`IN_PROGRESS`) | Driver trip |
| Cancel | `/trips/<id>/cancel/` | POST | `reason` | Trip | Driver trip |
| End trip | `/trips/<id>/end/` | POST | `latitude, longitude` | Trip (`COMPLETED`) | Driver trip |
| Manual arrive/depart | `/trips/<id>/advance-stop/` | POST | – | Trip | Driver / Helper trip (only if setting on) |
| Live GPS | `/gps/location/` | POST | `latitude, longitude, speed_kmh, heading, accuracy_meters, recorded_at` | `current_location, throttled` | Background service |
| Bus location | `/gps/buses/<bus_id>/location/` | GET | – | `latitude, longitude, speed_kmh, recorded_at` or `null` | Helper trip map |
| Roster | `/attendance/roster/` | GET | – | attendance rows for caller's active trip | Driver / Helper trip |
| Manual mark | `/attendance/manual/` | POST | `student_public_id, status` (`BOARDED`/`ABSENT`/`DROPPED`) | Attendance | Roster |
| QR scan | `/attendance/scan/` | POST | `qr_token` | Attendance | Helper / Driver scanner |
| Verify drop | `/attendance/verify-drop/` | POST | `student_public_id, code` | Attendance | Roster (PIN dialog) |
| SOS | `/emergency/sos/` | POST | `message` | EmergencyAlert | Driver / Helper trip |
| Parent children | `/parents/links/` | GET | – | `student{pickup_bus, drop_bus, pickup_stop, drop_stop, …}, relation` | Parent children |
| Parent live trips | `/gps/parent-live/` | GET | – | `[ {child, trip{stops,…}, location} ]` | Parent live / map |
| Attendance history | `/attendance/?student=<id>` | GET | – | paginated attendance | Child detail |
| Notifications | `/notifications/` | GET | `page` | paginated list with `data` deep-link payload | Notifications |
| Unread count | `/notifications/unread-count/` | GET | – | `unread_count` | Badge |
| Mark read | `/notifications/<id>/read/`, `/notifications/read-all/` | POST | – | – | Notifications |
| **Register device** (new) | `/notifications/devices/` | POST | `token, platform` | – | After login / token refresh |
| **Unregister device** (new) | `/notifications/devices/` | DELETE | `token` | – | Logout |

## 3. Role permissions honoured in the UI

| Action | Driver | Helper | Parent |
|---|---|---|---|
| Start / begin / end / cancel trip | yes | no (backend is driver-only) | no |
| Report GPS | yes | no | no |
| Advance stop | if setting on | if setting on | no |
| Mark attendance / QR / verify drop | yes | yes | no |
| SOS | yes | yes | no |
| Live bus map | own trip | assigned trip | own children only |

## 4. Backend addition: FCM push

* `DeviceToken` model (`apps.notifications`, migration `0002_devicetoken`): `user`, unique `token`, `platform`, `is_active`, `last_seen_at`.
* `POST/DELETE /api/notifications/devices/` — always bound to `request.user`.
* `apps/notifications/push.py` — `notify()` now calls `push.dispatch(created)` after it has written the in-app rows. Delivery runs after commit on a background thread, is a no-op unless `FIREBASE_CREDENTIALS_FILE` is set, never raises, and deactivates tokens FCM reports as unregistered.
* Payload `data`: `type` (NotificationType), `notification_id`, and whatever ids the existing trigger already stored (`trip_id`, `student_id`, `stop_id`, `bus_id`). No additional personal data is added.
