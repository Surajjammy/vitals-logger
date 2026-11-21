# Manual test checklist

Automated tests cover the logic with fake time and a fake API. This list checks
the things only a real device, real network and real server can show.

## Setup

1. Start the server: `cd server && node server.js` (http://localhost:3000).
2. Connect the Android phone (or emulator) with USB debugging and open the tunnel to the server:
   `adb reverse tcp:3000 tcp:3000`. Check it with `adb reverse --list`. It is lost when the cable is
   unplugged or adb restarts, so run it again if sync stops working.
   The server listens on `127.0.0.1` only (no auth, so it must not be on the network).
3. Start the app: `cd app && flutter run`. It talks to `http://127.0.0.1:3000`, which the tunnel forwards
   to the laptop. Override with `--dart-define=SERVER_URL=...` if needed.
4. In debug builds, the database icon in the top bar shows every row (status, attempts, last error).
5. See what the server has: `curl localhost:3000/readings`
6. Chaos commands (Git Bash; in PowerShell use `curl.exe` and escape the quotes):
3. See what the server has: `curl localhost:3000/readings`
4. Chaos commands (Git Bash; in PowerShell use `curl.exe` and escape the quotes):
   - `curl -X POST localhost:3000/_chaos -H "content-type: application/json" -d '{"failNext":3,"status":503}'`
   - `curl -X POST localhost:3000/_chaos -H "content-type: application/json" -d '{"latencyMs":4000}'`
   - `curl -X POST localhost:3000/_chaos -H "content-type: application/json" -d '{"dropNext":2}'`
   - Reset: `curl -X POST localhost:3000/_chaos -H "content-type: application/json" -d '{}'`

Tip: the server keeps data in memory. Restarting it empties it, but the app keeps its local rows.
That is a useful way to see "pending" rows re-upload.

## 1. Offline, then back online

With the USB tunnel, turning Wi-Fi or airplane mode on the phone does **not** cut the connection to
the server (it goes over the cable). To simulate offline, **stop the server** (see section 2). Airplane
mode only tests the real network path if the app talks to the laptop over Wi-Fi instead of the tunnel.

| Step | Expected |
|---|---|
| Go offline (stop the server). | App still opens, list still shows saved readings. |
| Add 3 readings (manual or "Read from device"). | Each saves instantly. Header shows "Not synced yet: 3". Rows show `pending`. |
| Open Charts. | The 3 readings appear as hollow rings (not synced). |
| Wait several minutes, then go back online (start the server). | Within at most a minute (retries are at most 60 s apart) the count drops to 0, rows show `synced`, "Last sync" shows a time. They did not turn `failed`, however long you waited. |
| `curl localhost:3000/readings` | Exactly 3 readings, sorted by time. |
| Charts again. | Points are now solid dots. |

## 2. Server down

| Step | Expected |
|---|---|
| Stop the server (Ctrl+C). Add a reading. | Saves instantly, stays `pending`. No error dialog, the app stays usable. |
| Wait 2 minutes. Open the database screen. | Row is still `pending`, **attempts 0**, last error `connectionError` (or a timeout). Retries get further apart (2, 4, 8, 16, 32, then 60 s). |
| Start the server again. | Within about a minute the row becomes `synced`. A new reading or reconnecting triggers an immediate retry. |

A server that **answers with an error** is different: it counts as an attempt, and after 5 the row
becomes `failed` (no retry button, known limit). Try it with chaos: `failNext` 10 with status 500, add a
reading, and watch attempts reach 5 and the status turn `failed`.

## 3. Slow server

| Step | Expected |
|---|---|
| Set `latencyMs` to 2000, add a reading. | Saves instantly. Becomes `synced` about 2 s later. UI never freezes. |
| Set `latencyMs` to 8000 (longer than the 5 s timeout), add a reading. | Row stays `pending`, attempts stay 0 (a timeout is a network error), `lastError` is a timeout. |
| Reset chaos. | The next retry succeeds. |
| Add 3 readings quickly while latency is 2000. | Uploaded one at a time, oldest first. Check server log or `GET /readings` order. |

## 4. Failing server and dropped connections

| Step | Expected |
|---|---|
| `failNext` 3 with status 503, add a reading. | 3 failures that **do** count as attempts (the server answered), then success on the 4th try. Row ends `synced`. |
| `dropNext` 2, add a reading. | Two `connectionError`s (checked against the real server: a dropped connection is a network error, so no attempt is used, attempts stay 0), then success. |
| Check `GET /readings`. | Still only one copy of the reading. |

## 5. Restart during sync

| Step | Expected |
|---|---|
| Set `latencyMs` to 4000, add a reading, then kill the app (swipe away) within 4 s. | Row was never confirmed. |
| Reset chaos, reopen the app. | Row is still `pending`, then syncs on app start. |
| `GET /readings`. | One copy, no duplicate. |

Known limit of the fake server: chaos delays or drops the request *before* storing it, so it cannot
produce "server stored it but the response was lost". That case is covered by the unit test
"app killed mid-sync" and by the server's idempotency (same id returns 200).

## 6. Device and limits

| Step | Expected |
|---|---|
| Tap "Read from device". | Button shows "Measuring...", then the fields fill with 118 / 76 / 68 after ~2 s. |
| Edit a field by hand, then Save. | Saved with the edited value. |
| Tap "Read from device", then immediately leave and come back. | No crash. |
| Type systolic 300, diastolic 80, pulse 70, Save. | Red "Check the reading again" message, nothing saved. |
| Press Save again. | Saved. |
| Type 300, Save (warning), change it to 310, Save. | Warning appears again (a new value is checked again). |

## 7. Charts

| Step | Expected |
|---|---|
| 7d / 30d chips. | "Daily averages". |
| 90d / 1y chips. | "Weekly averages", chart stays smooth. |
| Date picker with a range that has no data. | "No readings in this range". |
| Switch the phone to dark mode. | Lines and labels stay readable. |
