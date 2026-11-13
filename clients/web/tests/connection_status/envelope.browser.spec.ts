import { createHash } from 'node:crypto'
import { createServer } from 'node:http'
import type { Duplex } from 'node:stream'
import { expect, test } from '@playwright/test'

function frame(value: Record<string, unknown>): Buffer {
  const body = Buffer.from(JSON.stringify(value))
  const header = body.length < 126 ? Buffer.from([0x81, body.length]) : Buffer.from([0x81, 126, body.length >> 8, body.length & 255])
  return Buffer.concat([header, body])
}

test('malformed maintenance envelope closes and reconnects the real socket', async ({ page }) => {
  const sockets = new Set<Duplex>(), server = createServer()
  const id = '11111111-1111-4111-8111-111111111111'
  const base = { event_id: id, occurred_at: '2026-11-13T00:00:00Z' }
  let upgrades = 0
  server.on('upgrade', (request, socket) => {
    const key = request.headers['sec-websocket-key']
    if (!key) { socket.destroy(); return }
    upgrades++; sockets.add(socket)
    const accept = createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64')
    socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n' +
      `Sec-WebSocket-Accept: ${accept}\r\nSec-WebSocket-Protocol: boohtacord.heartbeat.v1\r\n\r\n`)
    socket.write(frame({ ...base, kind: 'connection.ready', payload: {} }))
    if (upgrades === 1) socket.write(frame({ ...base, kind: 'maintenance.snapshot', unexpected: true,
      payload: { version: 1, generation: id, revision: 1, active: false } }))
    socket.on('data', data => { if ((data[0] & 15) === 8) { socket.write(Buffer.from([0x88, 0])); socket.end() } })
    socket.on('end', () => socket.end()); socket.on('close', () => sockets.delete(socket))
  })
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve))
  try {
    const address = server.address()
    if (!address || typeof address === 'string') throw Error('missing listener')
    await page.goto('/tests/connection_status/heartbeat.html')
    await page.evaluate(url => (window as any).heartbeatFixture.start(url), `ws://127.0.0.1:${address.port}/realtime`)
    await expect.poll(() => upgrades, { timeout: 10_000 }).toBeGreaterThanOrEqual(2)
    await expect.poll(() => page.evaluate(() => (window as any).heartbeatFixture.state())).toBe('CONNECTED')
    await page.evaluate(() => (window as any).heartbeatFixture.stop())
  } finally {
    for (const socket of sockets) socket.destroy()
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()))
  }
})
