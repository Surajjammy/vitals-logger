const express = require('express');

const app = express();
app.use(express.json());

// In-memory store, keyed by the client-generated id.
const readings = new Map();

// Chaos settings, changed at runtime through POST /_chaos.
const defaultChaos = { failNext: 0, failStatus: 500, latencyMs: 0, dropNext: 0 };
let chaos = { ...defaultChaos };

app.post('/_chaos', (req, res) => {
  // Every call replaces the whole config, so {} resets everything.
  const { failNext = 0, status = 500, latencyMs = 0, dropNext = 0 } = req.body;
  chaos = { failNext, failStatus: status, latencyMs, dropNext };
  res.json(chaos);
});

// Chaos applies to /readings only, so /_chaos itself always works.
app.use('/readings', async (req, res, next) => {
  if (chaos.dropNext > 0) {
    chaos.dropNext--;
    return req.socket.destroy(); // close connection, no response
  }
  if (chaos.latencyMs > 0) {
    await new Promise((r) => setTimeout(r, chaos.latencyMs));
  }
  if (chaos.failNext > 0) {
    chaos.failNext--;
    return res.status(chaos.failStatus).json({ error: 'chaos failure' });
  }
  next();
});

app.post('/readings', (req, res) => {
  const { id, type, values, measuredAt } = req.body;
  if (!id || !['bp', 'temperature'].includes(type) || !values || isNaN(Date.parse(measuredAt))) {
    return res.status(400).json({ error: 'invalid reading' });
  }
  // Idempotent: a repeated id returns the stored reading, never a duplicate.
  if (readings.has(id)) {
    return res.status(200).json(readings.get(id));
  }
  const reading = { id, type, values, measuredAt: new Date(measuredAt).toISOString() };
  readings.set(id, reading);
  res.status(201).json(reading);
});

app.get('/readings', (req, res) => {
  const { from, to, type } = req.query;
  const fromMs = from ? Date.parse(from) : -Infinity;
  const toMs = to ? Date.parse(to) : Infinity;
  const result = [...readings.values()]
    .filter((r) => (!type || r.type === type))
    .filter((r) => {
      const t = Date.parse(r.measuredAt);
      return t >= fromMs && t <= toMs;
    })
    .sort((a, b) => Date.parse(a.measuredAt) - Date.parse(b.measuredAt));
  res.json(result);
});

const port = process.env.PORT || 3000;
// Local machine only: this fake server has no auth, so it must not listen on the
// network. A phone reaches it through `adb reverse tcp:3000 tcp:3000`. Set HOST=0.0.0.0 to open it up.
const host = process.env.HOST || '127.0.0.1';
if (require.main === module) {
  app.listen(port, host, () => console.log(`Fake server on http://${host}:${port}`));
}
module.exports = app;
