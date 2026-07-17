# FREIRAUM

FREIRAUM is a Flutter vertical slice for a German parking-sharing marketplace: drivers enter a destination and time window, compare demo private/commercial spaces, and inspect protected approximate listings.

## Platforms
Flutter Web, Android and iOS share the same Dart UI/domain code. App identifier: `de.freiraum.parking`.

## Prerequisites
Install a stable Flutter SDK with Dart 3, then run `flutter doctor`.

## Install
`flutter pub get`

## Run
- Web: `flutter run -d chrome`
- Android: `flutter run -d android`
- iOS: `flutter run -d ios` (macOS/Xcode required)

## Build Web
`flutter build web --release`

## Visible routes
- `/` launch experience
- `/discover` map-first discovery
- `/search` search results; configure static hosting to fall back all paths to `index.html` so browser refresh works.

## Demo limitations
All spaces, prices, availability and vehicle data are fictional demo data. No reservation, payment, authentication, backend or real gate access occurs. Exact private addresses are stored only as protected internal demo fields and are not shown in discovery/results.

## Map fallback
The app renders a local navigation-instrument city grid underneath markers, so tile/network failure never leaves a blank search experience.

## Reset demo state
Open the profile preview and use **Demo zurücksetzen** in later iterations; the persistence service already clears demo preference keys.

## Iteration 3: Booking-Backend

Für die lokale API wird PostgreSQL vorausgesetzt:

```bash
docker compose -f docker-compose.dev.yml up -d db
cd backend && pip install -e '.[test]'
alembic upgrade head
python -m app.db.seed
uvicorn app.main:app --reload
```

Die Flutter-App wird mit `--dart-define=API_BASE_URL=/api --dart-define=ALLOW_LOCAL_BOOKING_FALLBACK=true` gebaut. Solange die API nicht aktiviert ist, kennzeichnet die Oberfläche jede lokale Reservierung und speichert niemals eine geschützte Backend-Adresse.

Einmalig auf dem Produktionsserver:

```bash
sudo install -d -m 700 /srv/parkplatz
sudo chown "$USER":"$USER" /srv/parkplatz
cd /srv/parkplatz
./ops/bootstrap-server.sh
sudo install -m 644 ops/nginx/parkplatz.smarbiz.sbs.conf /etc/nginx/sites-available/parkplatz.smarbiz.sbs.conf
sudo nginx -t && sudo systemctl reload nginx
```

Der optionale Backend-Deploy wird ausschließlich durch das GitHub-Repository-Secret `DEPLOY_BACKEND_ENABLED=true` aktiviert.
# FREIRAUM Betriebsmodi und API-Architektur

```text
Flutter (Riverpod AppMode) ── /api/health ── FastAPI ── PostgreSQL
          │ nicht gesund
          └── expliziter lokaler Beta-Modus (SharedPreferences)
```

Beim Start wählt die App nach einer Datenbank-gestützten Gesundheitsprüfung
entweder den **API-Modus** oder – sofern per Build-Flag erlaubt – den sichtbar
gekennzeichneten **lokalen Beta-Modus**. Daten beider Modi werden nie gemischt.
Über „Erneut versuchen“ kann die Verbindung ohne Neustart geprüft werden.

## Lokale Entwicklung

```bash
docker compose -f docker-compose.dev.yml up -d
cd backend
alembic upgrade head
python -m app.db.seed  # idempotent
uvicorn app.main:app --reload
```

Flutter Web verwendet `--dart-define=API_BASE_URL=http://localhost:8000/api`,
Android Emulator `http://10.0.2.2:8000/api` und der iOS Simulator
`http://127.0.0.1:8000/api`. Der Produktionsbuild nutzt zusätzlich
`--dart-define=ALLOW_LOCAL_BOOKING_FALLBACK=true --pwa-strategy=none`.

## Produktion und Rollback

Einmalig `ops/bootstrap-server.sh` ausführen, `.env.production` (Modus `600`)
prüfen und die vorhandene Nginx-Konfiguration um den `/api/`-Proxy ergänzen,
ohne bestehende Zertifikatspfade zu ersetzen. Danach wird das Backend nur bei
dem GitHub-Secret `DEPLOY_BACKEND_ENABLED=true` durch
`ops/deploy-backend.sh` aktualisiert. Für ein Rollback den vorherigen Git-Stand
auschecken und das Deploy-Skript erneut ausführen; niemals
`docker compose down -v` verwenden. Das persistente Volume bleibt erhalten.

Erforderliche Actions-Secrets: `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`
und optional/standardmäßig deaktiviert `DEPLOY_BACKEND_ENABLED`. JWT-Secret und
Datenbankpasswort werden auf dem Server nur bei Fehlen erzeugt.

> Web-Härtung: `flutter_secure_storage` kapselt derzeit auch den Refresh-Token.
> Vor einem öffentlichen Hochsicherheitsbetrieb soll dieser in ein Secure,
> SameSite, HttpOnly Cookie migriert werden.

## Prüfungen

Backend: `ruff check app tests`, `alembic upgrade head`, Seed zweimal,
`pytest` und `docker build -t freiraum-api backend`. Flutter: `dart format`,
`flutter analyze`, `flutter test` sowie der Web-Release-Build ohne PWA-Cache.
