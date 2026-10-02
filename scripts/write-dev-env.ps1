# Writes env/dev.json for a physical Android device on the same network as this PC.
$ip = (
  Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
  Select-Object -First 1 -ExpandProperty IPAddress
)
if (-not $ip) {
  Write-Error "Could not detect LAN IP. Edit env/dev.physical.example.json manually."
  exit 1
}
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "env\dev.json"
@{
  API_BASE_URL = "http://${ip}:8000/api"
  OSRM_BASE_URL = "https://router.project-osrm.org"
  MAP_TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
  FIREBASE_API_KEY = ""
  FIREBASE_PROJECT_ID = ""
  FIREBASE_MESSAGING_SENDER_ID = ""
  FIREBASE_STORAGE_BUCKET = ""
  FIREBASE_ANDROID_APP_ID = ""
  FIREBASE_IOS_APP_ID = ""
  FIREBASE_IOS_BUNDLE_ID = ""
} | ConvertTo-Json | Set-Content -Path $out -Encoding UTF8
Write-Host "Wrote $out with API_BASE_URL=http://${ip}:8000/api"
Write-Host "Run: flutter run --dart-define-from-file=env/dev.json"
Write-Host "Backend: python manage.py runserver 0.0.0.0:8000"
