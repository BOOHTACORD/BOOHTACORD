import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'
import { describe, expect, it } from 'vitest'
function worker(state: unknown, duplicate = false) {
  const handlers: Record<string, (e: any) => void> = {}; const shown: any[] = []; const opened: string[] = []
  const self = { addEventListener: (name: string, fn: any) => { handlers[name] = fn },
    notificationState: { read: async () => state, claim: async () => ({ ok: true, duplicate }) },
    registration: { showNotification: async (...args: any[]) => { shown.push(args) } },
    clients: { matchAll: async () => [], openWindow: async (url: string) => { opened.push(url) } } }
  runInNewContext(readFileSync(new URL('../../../public/notification-sw.js', import.meta.url), 'utf8'),
    { self, importScripts() {}, URL, Date, location: { origin: 'https://chat.example.invalid' }, console })
  async function push(payload: unknown) { let pending: Promise<unknown> | undefined; handlers.push({ data: { json: () => payload }, waitUntil: (p: Promise<unknown>) => { pending = p } }); await pending }
  async function click(data: unknown) { let pending: Promise<unknown> | undefined; handlers.notificationclick({ notification: { data, close() {} }, waitUntil: (p: Promise<unknown>) => { pending = p } }); await pending }
  return { push, click, shown, opened }
}
const payload = () => ({ version: 1, generation: 2, binding_ref: '11111111-1111-4111-8111-111111111111', notification_ref: '22222222-2222-4222-8222-222222222222', group_ref: '33333333-3333-4333-8333-333333333333', template: 'direct_message', expires_at: new Date(Date.now() + 60000).toISOString() })
describe('privacy preserving notification worker', () => {
  it('keeps unknown, expired and malformed pushes visible without a route', async () => {
    for (const data of [payload(), null, { ...payload(), body: 'private message' }, { ...payload(), expires_at: '2000-01-01T00:00:00Z' }]) {
      const w = worker(null); await w.push(data); expect(w.shown).toHaveLength(1); expect(w.shown[0][1].data).toEqual({})
      expect(JSON.stringify(w.shown)).not.toContain('private message')
    }
  })
  it('has one visible presenter and makes duplicate replacement silent', async () => {
    const p = payload(); const state = { active: true, scope: 'opaque-scope', binding: p.binding_ref, generation: 2 }
    const first = worker(state); await first.push(p); expect(first.shown[0][1].renotify).toBe(true)
    const next = worker(state, true); await next.push(p); expect(next.shown[0][1].renotify).toBe(false)
    expect(next.shown[0][1].silent).toBe(true); expect(next.shown[0][1].data.ref).toBe(p.notification_ref)
    const old = worker({ ...state, generation: 3 }); await old.push(p); expect(old.shown[0][1].data).toEqual({})
  })
  it('opens only its own origin, putting opaque references in a fragment', async () => {
    const w = worker(null); await w.click({ ref: payload().notification_ref, generation: 2, url: 'https://evil.invalid' })
    expect(w.opened[0]).toMatch(/^https:\/\/chat.example.invalid\/#notification=/); expect(w.opened[0]).not.toContain('evil')
  })
})
