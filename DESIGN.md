# Vitals Logger: design notes

A prototype of offline-first sync. A patient records blood pressure and temperature,
the app keeps working with no connection, and readings sync to a server later.
Built to show the same shape as "instrument -> phone -> cloud".

## 1. Architecture

```
 +----------------+      raw bytes       +------------------+
 |  FakeBpCuff    | -------------------> | BpPacketDecoder  |
 | (BLE stand-in) |  Stream<Uint8List>   | bytes -> numbers |
 +----------------+                      +--------+---------+
                                                  | fills the form
                                                  v
 +-------------------------------------------------------------+
 |  UI (Riverpod ConsumerWidgets)                              |
 |  list screen / add form / charts / sync status              |
 +-------+---------------------------------------^-------------+
         | save                                  | Drift streams
         v                                       | (watchAll, watchRange,
 +----------------------+                        |  watchUnsyncedCount)
 |  ReadingsRepository  |------------------------+
 +----------+-----------+
            |  the only code that talks to Drift
            v
 +----------------------+        +-----------------------------+
 |  SQLite (Drift)      | <----- |  SyncService (outbox loop)  |
 |  table `readings`    |  read  |  oldest pending first, one  |
 |  = source of truth   |  queue |  at a time, backoff, lock   |
 +----------------------+  mark  +--------------+--------------+
                           synced                |  Dio POST /readings
                                                 v
                                      +-----------------------+
                                      |  Express server       |
                                      |  idempotent by id     |
                                      +-----------------------+

 Triggers for SyncService.syncNow():
   app start | after a reading is saved | connectivity returns | backoff timer
```

Riverpod provides the database, repository, API, cuff and sync service, so tests can
replace any of them (in-memory DB, fake API, fast fake cuff).

## 2. Why the local database is the source of truth

- The UI only reads Drift streams. It never waits for the network, so offline, slow
  and down-server cases look the same to the user: the reading is saved and shown at once.
- Saving is one local write. There is no "save failed because no signal" state.
- Sync becomes a background concern. It changes a row's `syncStatus`, the stream
  re-emits, and the UI updates itself. No code in the UI knows sync exists
  (the status line is just another stream).
- For a medical-style app this is also a safety point: a measurement taken with the
  cuff is never lost because the phone had no signal.

## 3. Outbox pattern

The `readings` table is its own outbox: each row has `syncStatus` (`pending | synced | failed`),
`attempts` and `lastError`. There is no separate queue to keep consistent with the data.

Loop in `SyncService.syncNow()`:

1. Read the oldest row that is not `synced` and has `attempts < maxAttempts`.
2. `POST` it with Dio.
3. On 200/201, mark it `synced` and go to step 1.
4. On failure there are two cases (see section 5):
   - **Network error** (offline, timeout, unreachable): record the error, keep the row `pending`,
     do not count an attempt, stop the loop and schedule a retry. This repeats for as long as needed.
   - **The server answered and refused** (4xx/5xx): record the error and `attempts + 1`. If attempts are
     left, stop the loop and schedule a retry. If that was the last attempt, the row becomes `failed`
     and the loop moves on to the next row.

Crash safety: a row becomes `synced` only after the server confirmed. If the app is killed
at any point earlier, the row is still `pending` and is sent again at next start. Because
the server is idempotent, the worst case is one harmless duplicate request, never a duplicate
reading and never a lost one. This is "at-least-once delivery + idempotent receiver",
which behaves like exactly-once.

One loop at a time: a `_running` flag. A second call while running returns immediately.
That is safe because the loop re-reads the queue every round, so a reading saved during
a sync is picked up by the loop that is already running.

## 4. Idempotency

- The client creates the id (uuid v4) when the reading is saved, before any network call.
- The server keeps readings by id. A repeated id returns the stored reading with **200**;
  a new one returns **201**. The client treats both as success.
- Result: any retry is safe: lost response, timeout, app killed after the server stored it,
  duplicate trigger. We never need to know whether an earlier attempt "really" arrived.

Why client-generated ids: a server-generated id would need a response before we know the
reading's identity, which is exactly the thing that may be lost on a bad connection.

## 5. Retry and backoff

- Delay after the n-th failure in a row: `2s * 2^(n-1)`, capped at 60 s (2, 4, 8, 16, 32, 60, 60...).
  The exponent is clamped, because a huge shift would overflow to 0 and retry with no wait.
- **Two kinds of failure are treated differently:**
  - *Network errors* (connection error, connect/send/receive timeout) mean the request never got an
    answer. That is not the reading's fault, so it does **not** use up an attempt. The row stays `pending`
    and retries every 60 s at most, for as long as the outage lasts. An outage of any length cannot turn
    a reading into `failed`.
  - *Server answers* (any HTTP error status) and other unexpected errors count as an attempt.
    Max attempts is 5. After that the row is `failed` and is no longer picked up.
- A new trigger (connectivity back, new reading, app start) cancels the wait, tries now, and starts the
  backoff over at 2 s.
- Timeouts: 5 s connect and 5 s receive, so a hung server counts as a failure, not a stuck loop.
- Why exponential with a cap: it gives a brief outage a fast recovery and a long outage
  little load. The cap keeps recovery time bounded. (Not implemented: random jitter, which matters
  when many devices fail at once and would otherwise all retry together.)
- After a failure that still has attempts left, the loop stops instead of skipping to the next row. The server is most
  likely unreachable, and skipping would send newer readings before older ones.
  The cost: one permanently bad row can delay the others until it reaches max attempts.

## 6. Conflict strategy

**Now: readings are append-only.** A measurement is a fact. It is created once on one device,
never edited. The only possible "conflict" is the same id arriving twice, and idempotency
resolves that (first write wins, same content anyway). Two devices cannot collide because
ids are random uuids.

**For editable data** (say patient profile or notes), my rule would be:

- Each record carries a `version` (or `updatedAt` from the server) that the client last saw.
- An edit is sent with that base version. If the server's version is newer, it rejects with 409
  and returns its current copy.
- Resolution, from simplest to most careful:
  1. **Field-level merge** when two edits touch different fields (keep both). This is the default.
  2. **Last write wins by server time**, for low-value fields such as a display name. Use server time,
     not the device clock, because phone clocks drift.
  3. **Ask the user**, for fields where a wrong choice matters (medication, dose). Show both versions.
- Never silently drop an edit. Keep the losing version until the user or a rule has decided.
- Deletes are soft (a `deletedAt` flag) so a late edit cannot resurrect or conflict with a missing row.

## 7. Trade-offs and known limits

| Choice | Benefit | Cost / limit |
|---|---|---|
| Table is the outbox | One source, no queue/data drift | Sync metadata lives in the data table |
| Stop loop on first failure | Keeps oldest-first order | A poison row delays the rest until max attempts |
| One upload per request | Simple, easy to reason about | Slow for large backlogs (a batch endpoint would help) |
| Only server answers count as attempts | A long outage never loses a reading | A server that is down but answers 503 still uses attempts; 5xx could be treated like a network error too |
| Network errors retry forever (max 60 s apart) | Offline-first really survives long outages | A permanently wrong server address retries forever, quietly, every minute |
| `failed` is final | Stops endless retries of refused readings | No "retry failed" button; needs a user or support action |
| Last sync time kept in memory | No schema change | Shows "never" after a restart |
| Chart averages per day/week | Fast for any range | Hides single spikes; a dangerous reading is averaged with others |
| Time is the device clock (`measuredAt`) | Matches when the measurement happened | A wrong phone clock gives wrong times; the server should also record its own receive time |
| Clinic limits ask once | Catches typos and bad measurements | Only a prompt, not a rule; limits are my placeholders, not clinical values |
| Fake cuff has no timeout | Simpler | If a real device never answers, the button stays on "Measuring..." |
| Server URL hard-coded | Simple | Needs config for real devices and environments |
| Chaos server stops before it stores | Simple to build | Cannot produce "stored but response lost"; covered by a unit test instead |

Not verified: I have run the unit, repository, widget and live-server tests. I have not run
the app on an emulator or a real device, so UI behaviour, real Bluetooth and platform
connectivity events are untested.

## 8. What I would add next

- **Background sync:** WorkManager (Android) and BGTaskScheduler (iOS) so readings upload when the
  app is closed. iOS decides when it runs, so the in-app triggers stay as well.
- **Auth and token refresh:** a Dio interceptor adds the access token; on 401 it refreshes once,
  holds other requests meanwhile, and retries. A failed refresh pauses sync and asks the user to log in
  (no attempts burned, since it is not the reading's fault).
- **Encryption:** the database is health data: encrypt at rest (SQLCipher with a key kept in the
  Keychain/Keystore), TLS with pinning for transport, and no readings in logs.
- **Conflict resolution for edits:** the version + field merge rule from section 6, tested with a
  fake server that returns 409.
- **Real BLE:** replace `FakeBpCuff` with a real implementation of the same `BpCuff` interface
  (flutter_reactive_ble or similar), including connect/disconnect handling, a timeout and a checksum
  check in the decoder.
- **Sync polish:** jitter in backoff, batch upload, "retry failed" action, persisted last-sync time,
  and splitting HTTP errors further: 4xx (bad data, never retry) vs 5xx (server trouble, retry like a
  network error).
- **Server-side:** persistent storage, validation of value ranges, and server receive time on each reading.

## 9. How I would explain this in an interview

Two-minute spoken summary:

> I built a small offline-first app called Vitals Logger. A patient records blood pressure and
> temperature, and it has to keep working with no connection and sync later, which is the same
> problem as an instrument that talks to a phone and a cloud platform.
>
> The main idea is that the local database is the source of truth. The UI only reads from a Drift
> database through streams, and saving a reading is just a local insert, so offline, slow and
> server-down all look the same to the user.
>
> Sync uses the outbox pattern. Every row has a status: pending, synced or failed, plus an attempts
> counter and the last error. A sync service takes the oldest unsynced row, uploads it with Dio, and
> marks it synced only after the server confirms. So if the app is killed at any point, the row is
> still pending and goes out again next time. It runs on app start, after a save, and when
> connectivity returns, and a flag makes sure two loops never run at once.
>
> To make retries safe, the client creates the id on the device and the server is idempotent: a
> repeated id returns 200 with the stored reading instead of creating a duplicate. That gives
> at-least-once delivery with an idempotent receiver, which behaves like exactly-once.
>
> Failures use exponential backoff, two seconds doubling up to a minute. I separate two kinds of
> failure: if the network is down or times out, the reading just waits and retries for as long as
> it takes, because that is not its fault. If the server answers and refuses it five times, the row
> is marked failed. I tested all of this with a fake API and fake time: success, 500, timeout,
> duplicate, killed mid-sync, backoff timing and max attempts. I also wrote a fake server with chaos
> modes for failures, latency and dropped connections, and ran the real service against it.
>
> For the device side, I simulated a Bluetooth cuff as a stream of raw bytes, a decoder for the final
> packet, and clinic limits that ask the user to check an out-of-range value once.
>
> Readings are append-only, so conflicts are rare. For editable data I would send a base version, let
> the server return 409, merge by field, and ask the user for critical fields.
>
> Next I would add background sync, token refresh, database encryption and real BLE. What I have not
> done is test it on many devices, and I know a few limits, like no retry button for failed readings.

Likely follow-up questions and short answers:

- **Why not just call the API and cache?** A cache can't take writes offline. Here writes are local first.
- **What if the server stored it but the response got lost?** The row stays pending, is resent, and the
  server returns 200 for the repeated id. No duplicate.
- **Why stop at the first failure?** To keep order and avoid hammering a server that is probably down.
- **What if two devices write?** Ids are random uuids and readings are never edited, so they cannot collide.
- **What does `take(1)` do on the device stream?** It takes one decoded result and cancels the subscription,
  so a second measurement cannot refill the form.
- **What would you test on a real device?** Everything in `MANUAL_TEST_CHECKLIST.md`, especially airplane
  mode and killing the app mid-sync.
