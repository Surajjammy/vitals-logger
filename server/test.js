// Run with: node test.js  (starts its own server on port 3100)
const assert = require('assert');
const http = require('http');
process.env.PORT = 3100;
const app = require('./server');

const base = 'http://localhost:3100';
const post = (path, body) =>
  fetch(base + path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
const chaos = (cfg) => post('/_chaos', cfg);
const reading = (id, at = '2026-01-01T10:00:00Z') =>
  ({ id, type: 'bp', values: { systolic: 120, diastolic: 80, pulse: 70 }, measuredAt: at });

async function run() {
  const server = app.listen(3100);
  const results = [];
  const check = async (name, fn) => { await fn(); console.log('PASS', name); };

  await check('POST new reading -> 201', async () => {
    assert.strictEqual((await post('/readings', reading('a'))).status, 201);
  });
  await check('POST same id again -> 200, no duplicate', async () => {
    assert.strictEqual((await post('/readings', reading('a'))).status, 200);
    const list = await (await fetch(base + '/readings')).json();
    assert.strictEqual(list.filter((r) => r.id === 'a').length, 1);
  });
  await check('GET sorted by measuredAt + range + type filter', async () => {
    await post('/readings', reading('c', '2026-01-03T10:00:00Z'));
    await post('/readings', reading('b', '2026-01-02T10:00:00Z'));
    await post('/readings', { id: 't', type: 'temperature', values: { temperatureF: 98.6 }, measuredAt: '2026-01-02T12:00:00Z' });
    const all = await (await fetch(base + '/readings')).json();
    assert.deepStrictEqual(all.map((r) => r.id), ['a', 'b', 't', 'c']);
    const ranged = await (await fetch(base + '/readings?from=2026-01-02T00:00:00Z&to=2026-01-02T23:59:59Z&type=bp')).json();
    assert.deepStrictEqual(ranged.map((r) => r.id), ['b']);
  });
  await check('chaos failNext: 2 x 503 then recovers', async () => {
    await chaos({ failNext: 2, status: 503 });
    assert.strictEqual((await post('/readings', reading('d'))).status, 503);
    assert.strictEqual((await post('/readings', reading('d'))).status, 503);
    assert.strictEqual((await post('/readings', reading('d'))).status, 201);
  });
  await check('chaos latencyMs: response takes >= 300ms', async () => {
    await chaos({ latencyMs: 300 });
    const start = Date.now();
    await post('/readings', reading('e'));
    assert.ok(Date.now() - start >= 290);
  });
  await check('chaos dropNext: connection closed, next call works', async () => {
    await chaos({ dropNext: 1 });
    await assert.rejects(post('/readings', reading('f')));
    assert.strictEqual((await post('/readings', reading('f'))).status, 201);
  });
  await check('reset chaos with empty body', async () => {
    await chaos({ failNext: 5 });
    await chaos({});
    assert.strictEqual((await post('/readings', reading('g'))).status, 201);
  });
  server.close();
  console.log('All server tests passed');
}
run().catch((e) => { console.error('FAIL', e); process.exit(1); });
