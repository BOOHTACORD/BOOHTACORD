import { createHash } from 'node:crypto'
import { createServer } from 'node:http'
import type { Duplex } from 'node:stream'
import { expect, test } from '@playwright/test'

function frame(kind: string): Buffer {
  const body = Buffer.from(JSON.stringify({ event_id: '11111111-1111-4111-8111-111111111111',
    occurred_at: '2026-11-13T00:00:00Z', kind, payload: {} }))
  const header = body.length < 126 ? Buffer.from([0x81, body.length]) : Buffer.from([0x81, 126, body.length >> 8, body.length & 255])
  return Buffer.concat([header, body])
}

test('reconnects after a live WebSocket silently stops sending', async ({ page }) => {
  test.setTimeout(65_000)
  const sockets = new Set<Duplex>(), server = createServer()
  let upgrades = 0, ended = 0
  server.on('upgrade', (request, socket) => {
    const key = request.headers['sec-websocket-key']
    if (!key || !request.headers['sec-websocket-protocol']?.split(',').map(s => s.trim()).includes('boohtacord.heartbeat.v1')) {
      socket.destroy(); return
    }
    upgrades++; sockets.add(socket)
    const accept = createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64')
    socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n' +
      `Sec-WebSocket-Accept: ${accept}\r\nSec-WebSocket-Protocol: boohtacord.heartbeat.v1\r\n\r\n`)
    socket.write(frame('connection.ready')); socket.write(frame('connection.heartbeat'))
    socket.on('data', data => { if ((data[0] & 15) === 8) { socket.write(Buffer.from([0x88, 0])); socket.end() } })
    socket.on('end', () => { ended++; socket.end() })
    socket.on('close', () => sockets.delete(socket))
  })
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve))
  try {
    const address = server.address()
    if (!address || typeof address === 'string') throw Error('missing loopback listener')
    await page.goto('/tests/connection_status/heartbeat.html')
    await page.evaluate(url => (window as any).heartbeatFixture.start(url), `ws://127.0.0.1:${address.port}/realtime`)
    await expect.poll(() => upgrades, { timeout: 5_000 }).toBe(1)
    await expect.poll(() => page.evaluate(() => (window as any).heartbeatFixture.state())).toBe('CONNECTED')
    await expect.poll(() => upgrades, { timeout: 50_000 }).toBeGreaterThanOrEqual(2)
    await expect.poll(() => ended, { timeout: 5_000 }).toBeGreaterThanOrEqual(1)
    await page.evaluate(() => (window as any).heartbeatFixture.stop())
  } finally {
    for (const socket of sockets) socket.destroy()
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()))
  }
})
