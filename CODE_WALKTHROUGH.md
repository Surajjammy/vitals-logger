# Code walkthrough

How the code works, flow by flow. Read `DESIGN.md` for *why*; this file is *where and how*.
File and function names are used instead of line numbers, so this stays correct as the code moves.

## 1. Map of the code

```
server/
  server.js            Express fake backend (in-memory), chaos switches
  test.js              proves idempotency + each chaos mode

app/lib/
  main.dart            App, HomeScreen (list + sync status), ReadingTile
  add_reading_screen.dart   Form: manual entry, "Read from device", limits check, save
  debug_db_screen.dart      Debug-only raw view of the table (hidden in release builds)
  providers.dart       Riverpod wiring: database, repository, API, cuff, sync service, streams
  data/
    database.dart      Drift table `readings`, SyncStatus enum, AppDatabase, openFileDatabase
    readings_repository.dart   The ONLY code that talks to Drift
  sync/
    readings_api.dart  ReadingsApi (interface), DioReadingsApi, createDio
    sync_service.dart  The outbox loop: upload, mark synced, retry, backoff
  device/
    fake_bp_cuff.dart  BpCuff (interface) + FakeBpCuff: raw byte packets as a stream
    bp_decoder.dart    bytes -> BpMeasurement
    vital_limits.dart  min/max per measurement
  charts/
    chart_data.dart    pure functions: per-day / per-week averages
    charts_screen.dart date-range filter + fl_chart line charts

app/test/              one test file per area (see section 10)
```

Generated file: `data/database.g.dart` (from `dart run build_runner build`). Do not edit it.

## 2. The data model (`data/database.dart`)

Table `readings` (Drift writes the column names in snake_case in SQLite):

| Column | Meaning |
|---|---|
| `id` | uuid created **on the device** (primary key) |
| `type` | `bp` or `temperature` |
| `systolic`, `diastolic`, `pulse` | set for `bp`, otherwise null |
| `temperatureF` | set for `temperature`, otherwise null |
| `measuredAt` | when the measurement happened (UTC) |
| `syncStatus` | `pending`, `synced` or `failed` |
| `attempts` | failed uploads **that the server answered** (see section 4) |
| `lastError` | text of the last error, null when OK |
| `createdAt` | when the row was saved (UTC) |

Sync state of a row:

```
          save                 server says 200/201
 (new) ---------> pending -------------------------> synced
                    |  ^                               (final)
 network error:     |  | stays pending, attempts unchanged, retry later
                    |  |
 server refused (4xx/5xx), attempts +1:
                    +--> pending (attempts < 5)
                    +--> failed  (attempts reaches 5)   (final, no retry button)
```

Drift stores `DateTime` as unix seconds and hands it back in local time. That is why the repository
calls `.toUtc()` on the way in and the API calls `.toUtc().toIso8601String()` on the way out.

## 3. Flow A: saving a reading

Files: `add_reading_screen.dart` -> `readings_repository.dart` -> SQLite.

1. User fills the form (typed, or filled by the device, flow D) and presses **Save**.
   `_AddReadingScreenState._save()` runs.
2. It parses the fields. A BP reading needs systolic + diastolic + pulse. A temperature reading needs
   temperature. Nothing filled in means nothing happens.
3. **Limits check:** `VitalLimits.check(...)` returns a list of problems. If there are problems and
   `_warning == null`, it sets `_warning` ("Check the reading again...") and **returns without saving**.
   Pressing Save again goes through because `_warning` is now set. Editing any field clears
   `_warning` (a listener on each controller), so a changed value is checked again.
4. `ReadingsRepository.addReading(...)` creates the id (`Uuid().v4()`) and inserts the row. Its
   `syncStatus` defaults to `pending` and `attempts` to 0.
5. `ref.read(syncServiceProvider).syncNow()` is called **without `await`**: saving never waits for
   the network. Then the screen closes.

The reading is now safe on the phone whatever the network does.

## 4. Flow B: the sync loop (`sync/sync_service.dart`)

`syncNow()` -> `_run()` -> `_drainQueue()`.

```
syncNow(): reset _networkFailures = 0, call _run()
_run():    if _running -> return        (one loop at a time)
           _running = true, cancel any waiting retry timer
           try { _drainQueue() } finally { _running = false }

_drainQueue():  loop
  1. queue = repo.getUploadQueue(maxAttempts)     -> rows not synced AND attempts < 5, oldest first
  2. empty? -> done
  3. take queue.first, call api.upload(it)
  4. outcome:
       success (200 or 201) -> _networkFailures = 0, repo.markSynced(id), onSynced(now), next row
       network error        -> repo.recordNetworkError(id, text)   (attempts unchanged)
                               _networkFailures++, Timer(backoff, _run), STOP loop
       server answered/other-> repo.recordFailure(id, text)        (attempts + 1)
                               attempts reached 5? -> row is `failed`, continue with next row
                               else Timer(backoff(attempts), _run), STOP loop
```

Details worth knowing:

- **Why `markSynced` comes after the upload:** if the app dies between the two, the row is still
  `pending`, so it is sent again. The server is idempotent (section 7), so that is harmless.
- **Network error** (`SyncService.isNetworkError`): a `DioException` of type `connectionTimeout`,
  `sendTimeout`, `receiveTimeout` or `connectionError`. No reply came, so it is not the reading's
  fault. Verified against the real server: a dropped connection is `connectionError`, and a slow reply
  is `receiveTimeout`.
- **Backoff** (`backoffDelay`): `2s * 2^(n-1)`, capped at 60 s. The exponent is clamped to 20, because a
  big shift would overflow to 0 and retry with no wait.
- **Why the loop stops after a failure:** to keep oldest-first order and not hammer a server that is
  probably down. The exception is a row that just reached `failed`: the loop moves on so it cannot
  block the rest.
- **Lock:** the `_running` flag. There is no `await` between the final queue check and
  `_running = false`, so a trigger cannot slip through the gap. A trigger that arrives while the loop is
  running is ignored, and that is safe because the loop re-reads the queue every round.

`_describe(e)` turns an error into the text saved in `lastError`: `HTTP 503` if the server answered, or
the Dio error type name (`connectionError`, `receiveTimeout`...) otherwise.

### The network layer (`sync/readings_api.dart`)

- `ReadingsApi` is an interface with one method, `upload(Reading)`. It completes normally on success
  and throws on any failure. Tests replace it with a fake.
- `DioReadingsApi.upload` POSTs `{id, type, values, measuredAt}` to `/readings`. Dio throws on any
  non-2xx, so a 200 (already stored) and a 201 (new) both count as success. That is the client half of
  idempotency.
- `createDio(baseUrl)` sets 5 s connect and 5 s receive timeouts, so a hung server becomes a
  `*Timeout` error instead of a stuck loop.

## 5. Flow C: how the screen updates by itself

```
 SQLite --(Drift .watch())--> ReadingsRepository stream --> Riverpod StreamProvider --> widget rebuild
```

- `readingsProvider` (all rows, newest first) feeds the list on `HomeScreen`.
- `unsyncedCountProvider` feeds "Not synced yet: N" (counts everything that is not `synced`).
- When the sync service calls `markSynced`, Drift notices the table changed, the streams emit again,
  and the row turns from `pending` to `synced` on screen. No UI code mentions sync.
- "Last sync" comes from `lastSyncProvider`, set by `SyncService.onSynced`. It lives in memory only,
  so it shows "never" after a restart.
- **The UI never reads the network.** That is the offline-first rule.

## 6. Flow D: triggers for syncing (`providers.dart`, `syncServiceProvider`)

| Trigger | Where |
|---|---|
| App start | `syncServiceProvider` calls `service.syncNow()` when it is first created. `HomeScreen.build` reads it (`ref.watch(syncServiceProvider)`), which creates it. |
| After saving | `_save()` in `add_reading_screen.dart` |
| Connectivity returns | `Connectivity().onConnectivityChanged` listener in the provider: any result other than `none` calls `syncNow()` |
| Backoff timer | `Timer(backoff, _run)` set by the service itself after a failure |

A new `syncNow()` (the first three) also resets the backoff to 2 s. The timer calls the private `_run`
instead, so it does **not** reset it. That is why the waits keep growing during a long outage.

Server address (`providers.dart`): `http://127.0.0.1:3000` by default, or `--dart-define=SERVER_URL=...`.
On a phone that address works through the USB tunnel `adb reverse tcp:3000 tcp:3000`.

## 7. The server (`server/server.js`)

- Readings live in a `Map` keyed by `id` (memory only; restarting empties it).
- `POST /readings`:
  1. validate (`id`, `type` is `bp` or `temperature`, `values`, parseable `measuredAt`), else **400**
  2. id already in the map -> return the stored reading with **200** (idempotent, no duplicate)
  3. otherwise store it and return **201**
- `GET /readings?from=&to=&type=`: filter, sort by `measuredAt`.
- `POST /_chaos`: replaces the whole chaos config on every call (`{}` resets). Fields: `failNext` (+ `status`),
  `latencyMs`, `dropNext`. A middleware on `/readings` applies them: drop -> `socket.destroy()`,
  latency -> wait, fail -> return the status. `/_chaos` itself is never affected.
- It listens on `127.0.0.1` only (override with `HOST`), because it has no authentication.

## 8. Flow E: reading from the device (`device/`, `add_reading_screen.dart`)

1. Tap **Read from device** -> `_readFromDevice()` gets `bpCuffProvider` (a `FakeBpCuff`).
2. It builds a pipeline on `cuff.packets` (a broadcast `Stream<Uint8List>`):
   `.map(decoder.decode)` -> `.where((m) => m != null)` -> `.cast<BpMeasurement>()` -> `.take(1)` -> `.listen(...)`
3. `cuff.startMeasurement()` starts a timer. `FakeBpCuff` sends 5 short packets (4 bytes, live pressure),
   then one 10-byte final packet, then stops.
4. `BpPacketDecoder.decode` returns `null` for packets of 9 bytes or fewer. For longer ones it reads
   `byte[2]` systolic, `byte[4]` diastolic, `byte[8]` pulse. It does not judge the values.
5. `take(1)` delivers the first decoded result and **cancels the subscription**, so a later measurement
   cannot refill the form (no duplicates).
6. The listener fills the text fields. The user can still edit them or type everything by hand.

`BpCuff` is an interface, so a real BLE class can replace `FakeBpCuff` in `bpCuffProvider` only.

## 9. Flow F: charts (`charts/`)

1. `chartRangeProvider` holds the date range (default: last 30 days). The chips and the date picker change it.
2. `chartReadingsProvider` watches `repo.watchRange(from, to)`, so charts update live.
3. `useWeeklyBuckets` is true when the range is longer than 60 days. Then `aggregate(...)` averages per
   week (Monday start) instead of per day, so a year is about 53 points however many readings exist.
4. `dayNumber` turns a date into "days since 1970" using the local calendar date, so daylight-saving
   cannot shift points. `bpPoints` and `temperaturePoints` call `aggregate` with different `pick` functions.
5. A `ChartPoint` has `hasUnsynced`: true if any reading in that bucket is not `synced`.
   `VitalsLineChart` draws such points as a larger hollow ring, so it differs by shape and not only by colour.
6. Temperature has its own chart and y-axis, never sharing a scale with mmHg/bpm.

## 10. Where each behaviour is tested

| Behaviour | Test file |
|---|---|
| Insert, streams, queue order, markSynced, recordFailure, recordNetworkError | `readings_repository_test.dart` |
| Success, 500, timeout, duplicate, killed mid-sync, no double loop, backoff in fake time, long outage, max attempts, Dio 200/201/500 | `sync_service_test.dart` |
| Decoder (short, 9-byte, out-of-range), limits, cuff stream, `take(1)` | `bp_decoder_test.dart` |
| Limits warning (save twice), device button fills the form | `add_reading_screen_test.dart` |
| Averages, weekly buckets, unsynced flag, `watchRange`, charts screen | `chart_data_test.dart` |
| Debug database screen | `debug_db_screen_test.dart` |
| Server: idempotency and each chaos mode | `server/test.js` |

Run: `cd app && flutter test` and `cd server && node test.js`.

## 11. Three end-to-end scenarios

**Online:** Save -> row `pending` -> `syncNow()` -> POST -> 201 -> `markSynced` -> list shows `synced`, count drops.

**Offline for ten minutes:** Save x3 -> rows `pending`. First POST fails with `connectionError`:
`recordNetworkError`, retry in 2 s, then 4, 8, 16, 32, 60, 60... Attempts stay 0 and rows never become
`failed`. Server comes back -> the next retry (or a new trigger) gets through -> all rows `synced`, oldest first.

**App killed mid-upload:** the server stored the reading but the app died before `markSynced`. Next start,
`syncNow()` finds the row still `pending` and sends it again. The server finds the id, returns **200** and
stores nothing new. The app marks it `synced`. No duplicate, no loss.

## 12. Debug tools

- Database icon in the app bar (debug builds only): `DebugDbScreen` shows every row with status,
  attempts and last error.
- Phone database from the laptop (Git Bash): `adb exec-out run-as com.example.vitals_logger cat app_flutter/vitals.sqlite > vitals.sqlite`
  then `sqlite3 vitals.sqlite "SELECT ... FROM readings;"`.
- Server contents: `curl localhost:3000/readings`.

## 13. Things not in the code (on purpose)

No download sync (server -> device), no auth or HTTPS, no encryption at rest, no background sync when the
app is closed, no "retry failed" button, last-sync time not saved across restarts. `DESIGN.md` section 7
and 8 explain the trade-offs and what comes next.
