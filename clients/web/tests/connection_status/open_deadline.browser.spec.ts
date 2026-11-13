import { createServer, type Server } from 'node:http'
import type { Duplex } from 'node:stream'
import { expect, test } from '@playwright/test'

test('retries a real HTTP upgrade that never receives a response', async ({ page }) => {
  test.setTimeout(35_000)
  const sockets = new Set<Duplex>()
  let upgrades = 0, closed = 0, ended = 0
  const server: Server = createServer()
  server.on('upgrade', (_request, socket) => {
    upgrades++; sockets.add(socket)
    socket.on('end', () => { ended++; socket.end() })
    socket.on('close', () => { closed++; sockets.delete(socket) })
    socket.resume()
  })
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve))
  try {
    const address = server.address()
    if (!address || typeof address === 'string') throw Error('missing loopback listener')
    await page.goto('/tests/connection_status/deadline.html')
    await page.evaluate(url => (window as any).deadlineFixture.start(url), `ws://127.0.0.1:${address.port}/realtime`)
    await expect.poll(() => upgrades, { timeout: 5_000 }).toBe(1)
    await expect.poll(() => upgrades, { timeout: 20_000 }).toBeGreaterThanOrEqual(2)
    await expect.poll(() => ended, { timeout: 5_000 }).toBeGreaterThanOrEqual(1)
    await expect.poll(() => closed, { timeout: 5_000 }).toBeGreaterThanOrEqual(1)
    expect(await page.evaluate(() => (window as any).deadlineFixture.attempts())).toBe(2)
    await page.evaluate(() => (window as any).deadlineFixture.stop())
  } finally {
    for (const socket of sockets) socket.destroy()
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()))
  }
})
