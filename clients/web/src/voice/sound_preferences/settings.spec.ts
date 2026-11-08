import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { expect, it } from 'vitest'
import Settings from './Settings.vue'

const settings = { enabled: true, joined: true, left: false, started: true, stopped: false, allow_custom: true, volume: 40 }
it('renders separate switches, bounded volume and unsynchronised state', async () => {
  const html = await renderToString(createSSRApp(Settings, { settings, ready: true, unsynchronised: true }))
  for (const text of ['Звуки голосового канала', 'Кто-то вошёл', 'Кто-то вышел', 'Трансляция началась', 'Трансляция закончилась', 'Мелодии входа других участников', 'Не синхронизировано']) expect(html).toContain(text)
  expect(html).toContain('max="100"'); expect(html).toContain('min="0"'); expect(html).toContain('value="40"')
  expect((html.match(/type="checkbox"/g) ?? []).length).toBe(6)
  expect((html.match(/>Прослушать<\/button>/g) ?? []).length).toBe(4)
})

it('disables controls while preferences are unavailable', async () => {
  const html = await renderToString(createSSRApp(Settings, { settings, ready: false, unsynchronised: false }))
  expect((html.match(/disabled/g) ?? []).length).toBe(11)
})
