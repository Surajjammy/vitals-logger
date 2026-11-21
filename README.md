# Vitals Logger

A learning prototype of **offline-first data sync** in Flutter. A patient records blood pressure
(systolic, diastolic, pulse) and temperature. Readings are saved on the phone first and uploaded to a
fake server later. Not for real patient data: no authentication, no HTTPS, no encryption.

## Documents

| File | What it is |
|---|---|
| `CODE_WALKTHROUGH.md` | How the code works, flow by flow, with file and function names |
| `DESIGN.md` | Why it is built this way, trade-offs, what comes next, 2-minute interview summary |
| `MANUAL_TEST_CHECKLIST.md` | Things to try by hand on a device (offline, server down, slow, restart) |

## Layout

- `server/` Node + Express fake backend (in memory)
- `app/` Flutter app (Drift/SQLite, Riverpod, Dio, fl_chart)

## Run it

Needs Node, Flutter and (for a real phone) `adb`.

```bash
# 1. Server (listens on 127.0.0.1:3000 only)
cd server
npm install
node server.js

# 2. Phone or Android emulator: forward the phone's port 3000 to the laptop (re-run after unplugging)
adb reverse tcp:3000 tcp:3000

# 3. App
cd app
flutter pub get
dart run build_runner build      # generates data/database.g.dart
flutter run
```

Use `--dart-define=SERVER_URL=http://<address>:3000` to point the app somewhere else.

## Tests

```bash
cd app && flutter test      # repository, sync, decoder, screens, charts
cd server && node test.js   # idempotency and chaos modes
```

## Look at the data

- In the app (debug builds): the database icon in the top bar.
- On the server: `curl localhost:3000/readings`.
- Simulate offline: stop the server, or `adb reverse --remove tcp:3000` (and `adb reverse tcp:3000 tcp:3000` to restore).
