# SafeRoute Mobile (Flutter)

One Android/iOS app for **Drivers, Helpers and Parents**. It is a client of the
existing SafeRoute Django API. The app holds no business logic or data store of its own:
trip transitions, stop order, geofencing, attendance rules, notification
recipients and tenant isolation are all decided by the backend, the same as
for the React web app.

* Endpoint audit and feature → API mapping: [`docs/API_MAPPING.md`](docs/API_MAPPING.md)
* School admins and super admins keep using the web dashboard. The app tells them so after sign-in.

## Architecture

```
UI (screens/, widgets/)
  → Controllers (providers/, ChangeNotifier + provider)
    → Repositories (repositories/)
      → ApiClient (core/api/: Dio, JWT interceptor, error mapping)
        → Django REST API
```

| Folder | Contents |
|---|---|
| `lib/core/api` | `api_client.dart` (unwraps `{success,message,data}`), `auth_interceptor.dart` (Bearer + single-flight refresh, logout on refresh failure), `api_endpoints.dart`, `api_exception.dart` |
| `lib/core/location` | `location_service.dart` (permission flow with explanations), `gps_tracking_service.dart` (Android foreground service that reports trip GPS) |
| `lib/core/firebase` | `notification_service.dart` (FCM init, permission, token register/refresh/unregister, foreground/background/terminated handling) |
| `lib/core/navigation` | `deep_link_router.dart` (role-aware routing from notification payload ids) |
| `lib/core/storage` | `token_storage.dart` (JWTs in `flutter_secure_storage`) |
| `lib/models` | Plain models parsed from backend JSON |
| `lib/repositories` | One per backend area: auth, trips, attendance, transport, notifications |
| `lib/providers` | `AuthController`, `OperatorTripController` (driver + helper), `ParentController`, `NotificationsController` |
| `lib/screens` | `auth/`, `home/`, `operator/` (driver & helper trip dashboard), `parent/`, `notifications/`, `profile/` |

## Configuration

All build-time settings are passed with `--dart-define-from-file`. Copy the example and fill it in:

```bash
cp env/dev.example.json env/dev.json
```

| Key | Meaning |
|---|---|
| `API_BASE_URL` | Django API root including `/api`. Android emulator → host machine: `http://10.0.2.2:8000/api`. Physical phone: `http://<your-PC-LAN-IP>:8000/api`. Production: `https://…/api`. |
| `OSRM_BASE_URL` | Road-route service (same one the web uses). Default: public demo server `https://router.project-osrm.org`. |
| `MAP_TILE_URL` | Map tiles. Default: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`. |
| `FIREBASE_*` | **Public** Firebase client options. Leave empty to run without push (in-app notifications still work). |

`env/*.json` files are gitignored (only `*.example.json` are tracked). Put only
public values in them. Never put the Django secret key, database passwords,
Firebase server keys or service-account private keys in the mobile app.

Cleartext `http://` is allowed **only in debug builds**
(`android/app/src/debug/res/xml/network_security_config_debug.xml`). Release builds need HTTPS.

### Backend for local mobile testing

The emulator reaches the host through `10.0.2.2`, so Django must accept that host:

```powershell
# backend/.env
ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2
# then
.\env\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

For a **physical phone**, generate `env/dev.json` with your PC's LAN IP:

```powershell
.\scripts\write-dev-env.ps1
flutter run --dart-define-from-file=env/dev.json
```

With `DEBUG=True`, Django accepts any Host by default (`ALLOWED_HOSTS_DEBUG_ANY` in `backend/.env.example`), so you do not need to edit `ALLOWED_HOSTS` every time your Wi‑Fi IP changes.

### Kotlin / Firebase build warning

If Flutter warns that `firebase_core` applies the Kotlin Gradle Plugin (KGP), it is a known plugin notice until Firebase ships built-in Kotlin support. SafeRoute already uses Flutter's Android Kotlin block; keep `firebase_core` / `firebase_messaging` on the latest versions allowed by `pubspec.yaml`.

## Run & build

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json          # debug on emulator/device
flutter test                                               # unit tests
flutter build apk --release --dart-define-from-file=env/prod.json
flutter build appbundle --release --dart-define-from-file=env/prod.json   # Play Store
```

Android application id: `com.saferoute.app`, minSdk 23.

**Release signing** is not configured yet. `android/app/build.gradle.kts` still signs
release builds with the debug key. Before publishing, create an upload keystore, keep
`key.properties` and the `.jks` file out of git, and add a `signingConfigs { release { … } }` block
([Flutter guide](https://docs.flutter.dev/deployment/android#signing-the-app)).

Windows notes: `android/gradle.properties` sets `kotlin.incremental=false`, because Kotlin's incremental
cache fails when the pub cache (C:) and the project (D:) are on different drives. If
`flutter test` reports `%PROGRAMFILES(X86)% environment variable not found`, set it in the shell
(`$env:ProgramFiles(x86)="C:\Program Files (x86)"`).

## Firebase push notifications

The backend decides who receives each notification. It already writes in-app notifications through
`apps.notifications.services.notify()`, and it now also sends those to the recipients' registered
devices through FCM.

1. In the Firebase console, create a project and add an **Android app** with package `com.saferoute.app`
   (and an iOS app with your bundle id, if needed).
2. From *Project settings → General → Your apps*, copy the **public** values into `env/<flavor>.json`:
   `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`,
   `FIREBASE_STORAGE_BUCKET`, `FIREBASE_ANDROID_APP_ID` (`1:…:android:…`), and optionally the iOS values.
   The app initialises Firebase from these values, so no `google-services.json` or Gradle plugin is needed.
3. **Server only:** create a service-account key (*Project settings → Service accounts*), store it outside the
   repo or under `backend/secrets/` (gitignored), and set in `backend/.env`:
   `FIREBASE_CREDENTIALS_FILE=/absolute/path/to/service-account.json`.
   Without this, push is disabled and nothing else changes.
4. `pip install -r backend/requirements.txt` (adds `firebase-admin`) and `python manage.py migrate`
   (creates `notifications_devicetoken`).

Client behaviour:
* After sign-in, the app explains why it needs notifications, asks for permission once, and then registers
  the FCM token with `POST /api/notifications/devices/`. Token refreshes are re-registered. Several devices per user are supported.
* On sign-out, the token is unregistered (`DELETE /api/notifications/devices/`) and deleted from FCM, so
  the next person using that phone doesn't get the previous user's alerts.
* **Foreground:** a SnackBar with an *Open* action. **Background / terminated:** the OS shows the notification; tapping it opens the app.
* **Deep links** use only the ids in the payload (`type`, `trip_id`, `student_id`, `notification_id`).
  Parents go to the live trip or child screen, and drivers/helpers get their trip dashboard refreshed. The destination
  screen always reloads from the API, which re-checks access.

## GPS tracking (driver)

* Starting a trip first explains the location need, then asks for permission (while-in-use is enough), gets a
  fix, and calls `POST /api/trips/start/`.
* While the driver's trip is active (`STARTED`, `IN_PROGRESS`, `PAUSED`, `EMERGENCY`) and the school has
  `gps_tracking_enabled`, an **Android foreground service** (type `location`, with a persistent notification)
  reports `POST /api/gps/location/` every 10 s, the same cadence as the web driver dashboard. It keeps running in the
  background and with the screen off. It never runs when there is no active trip.
* Offline or 5xx: points are queued (max 60), sent oldest-first, and capped per cycle to stay under the backend throttle.
  `409` (no active trip) stops the service. `401` after a failed refresh stops it and signs the user out.
* If the Google fused provider refuses (e.g. "Location Accuracy" declined), the reporter falls back to the platform GPS provider.
* The dashboard shows live status: sharing, weak signal, offline + queued, GPS off, permission revoked, with a restart action.
* Some OEMs (Xiaomi, Oppo, Vivo, Samsung "sleeping apps") can kill foreground services. For drivers' phones, exclude
  SafeRoute from battery optimisation.

## Maps

`flutter_map` with OpenStreetMap tiles. The road route comes from OSRM (the same service and fallback as the web's
`mapProviderService.js`). The completed and remaining path is split at the current stop, as on the web. Parents see
only the bus location returned by `/api/gps/parent-live/`. The app never invents a position, and old positions are flagged as possibly outdated after 60 s.

Why `flutter_map` rather than `google_maps_flutter`: the web uses Leaflet with OSM (`map_provider` defaults to
`LEAFLET`), so the same tiles and route logic apply on both clients. Google Maps would need a restricted Android and iOS
API key in the app. The backend's `google_maps_api_key` is a school setting that the mobile roles can't read.

All coordinates come from the API, and nothing is hard-coded:

| Marker | Source |
| --- | --- |
| Bus | Driver: its own GPS fix, the same fix it sends to `POST /gps/location/`. Helper: `/gps/buses/<id>/location/`. Parent: `parent-live.location`. |
| Trip stops (numbered, in backend order) | `TripSerializer.trip_stops` for the driver and helper; `parent-live.trip.stops` for parents |
| School | `School.latitude/longitude` from `/api/schools/`, which is scoped to the caller's school. Hidden when the school has no coordinates. |
| Child pickup / drop point | the student's `pickup_stop` / `drop_stop` from `/parents/links/`, drawn separately when not on the displayed trip |

Tapping a marker opens a details sheet. For stops it shows the status, scheduled time, arrival and departure times,
and the students at that stop (driver and helper). The map has go-to-bus/follow, fit-all and zoom controls. The
morning or evening order is whatever the backend put in `TripStop.sequence`; the app never reorders it. The school
is shown as a marker but isn't added to the route line, which matches the web: the backend doesn't model the school
as a trip stop. If OSRM is unreachable, the ordered stops are joined by a grey dashed line, and a note says so.

**Not available from the existing API:** parents can't get the driver's name or phone number. `parent-live`
doesn't include them, and parents' `/api/trips/` fails (see the pre-existing issues). So the parent app shows bus
number, route, trip status and the next stop, but no driver details.

**Production:** the public OSM tile servers and the OSRM demo server are not meant for production traffic
(this applies to the web app too). Point `MAP_TILE_URL` and `OSRM_BASE_URL` at a commercial tile provider and a
self-hosted OSRM instance.

## Role behaviour

| | Driver | Helper | Parent |
|---|---|---|---|
| Start morning/evening trip, start driving, cancel, end | ✓ | – (backend: driver-only) | – |
| Live GPS reporting | ✓ | – | – |
| Board / absent / drop, drop-PIN verification, QR scan | ✓ | ✓ | – |
| Manual arrive/depart | if school allows | if school allows | – |
| SOS | ✓ | ✓ | – |
| Map | own position | bus position from server | own children's buses only |
| Children, pickup/drop stops, attendance history, live trip | – | – | ✓ |

Start buttons show *START MORNING TRIP* / *START EVENING TRIP*. While a trip is running, the dashboard shows that trip.
Once today's run of that type has completed or been cancelled, the button is locked as *… COMPLETED* / *… CANCELLED*.
Duplicate starts are blocked in the UI and rejected by the backend.

## Backend changes made for mobile (additive only)

| File | Change |
|---|---|
| `apps/notifications/models.py` | New `DeviceToken` model (+ migration `0002_devicetoken`) |
| `apps/notifications/views.py`, `serializers.py`, `urls.py` | New `POST/DELETE /api/notifications/devices/`, bound to `request.user` |
| `apps/notifications/push.py` | New: FCM delivery after commit on a background thread. No-op without credentials, never raises, prunes dead tokens |
| `apps/notifications/services.py` | `notify()` calls `push.dispatch(created)` just before returning. Existing behaviour is unchanged |
| `config/settings.py`, `.env.example`, `requirements.txt` | `FIREBASE_CREDENTIALS_FILE` setting, `firebase-admin==7.7.0` |
| `apps/notifications/tests.py` | 8 tests for the above |

No existing endpoint, response field or business rule was changed.

## Testing performed

* `flutter analyze`: no issues. `flutter test`: 9 unit tests (parsing of real response shapes, error mapping, distance formula).
* Backend: `manage.py check`, `makemigrations --check` (no pending), `manage.py test apps.notifications` (8 passing).
* **API end-to-end (63/63 checks)** against a throwaway SQLite database with two schools, run with the exact calls the app makes:
  driver morning and evening runs (backend-reversed evening order, boarding required before *begin*, end refused
  while a student is still boarded, wrong/right drop PIN), helper attendance/advance-stop/SOS, plus isolation checks: helper can't
  start/begin/end or post GPS; another driver in the same school and a driver of another school can't start or act on
  the trip or read its bus location; parent A only sees their own children and live trip; parent B (other school) sees
  nothing from school A; a QR code of another school's student is rejected; parents can't mark attendance, start trips or raise SOS;
  users can't read other users' notifications; device tokens are bound to their owner.
* **On an Android emulator (API 37)** against that server: login, notification and location explanations
  followed by OS prompts, driver start → start driving → manual arrive/depart → end trip; GPS reached the server every 10 s
  **with the app backgrounded and the screen off**; the service stopped when the trip ended; the completed morning
  run locked its button; sign-out; parent live map with moving bus, distance/ETA, notification list, a
  notification deep link to an ended trip, and the child detail screen.

Not tested yet:
* Real FCM delivery (needs your Firebase project), including background/terminated taps.
* The helper UI on a device (helper permissions were covered at API level).
* iOS builds (Info.plist usage strings and background modes are set, but APNs/Firebase iOS setup and a Mac are needed).
* Physical-phone battery-optimisation behaviour.
* The web app in a browser. No frontend file was changed, and the backend endpoints the web uses were exercised by the API E2E.

## Pre-existing backend issues found (not changed)

1. `POST /api/auth/logout/` returns 500: `RefreshToken.blacklist()` is called but
   `rest_framework_simplejwt.token_blacklist` isn't in `INSTALLED_APPS`. The mobile app still clears its tokens locally.
2. `GET /api/trips/…` returns 500 for PARENT users (`FieldError` on `trip_stops__stop__students`). The app uses `/api/gps/parent-live/` like the web.
3. WebSocket `/ws/gps/<bus>/` fails for parents (`bus.students` doesn't exist). The app polls, like the web.
4. The web helper dashboard shows *Start trip* and *Cancel*, but the backend rejects both for helpers (403).
5. `manage.py seed_full` uses outdated enum values (`route_type="pickup"`, `status="in_progress"`).

## Production checklist

* Backend: `pip install -r requirements.txt`, `migrate`, `FIREBASE_CREDENTIALS_FILE` (server-side file, 0600), HTTPS, and
  `ALLOWED_HOSTS` for the API domain. Redis must be running for the web's realtime features.
* App: `env/prod.json` with the HTTPS `API_BASE_URL`, production tile/OSRM URLs and Firebase client values. Release signing.
  Bump `version:` in `pubspec.yaml`.
* Play Console: declare the foreground-service **location** use (the app shares location only during an active trip, with a
  visible notification) and complete the location data-safety section.
