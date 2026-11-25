import { publicRevision } from './public.mjs'

const origin = 'https://v.bootybay.ru'

export async function createBrowserAdapter(chromium, credentials) {
  if (!credentials.login || !credentials.password || !credentials.channel) throw Error('Smoke identity unavailable')
  const browser = await chromium.launch({ channel: 'chrome', headless: true,
    args: ['--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream'] })
  const context = await browser.newContext()
  const page = await context.newPage()
  page.setDefaultTimeout(20000)
  await page.addInitScript(() => {
    window.__smokePeers = []
    const Native = window.RTCPeerConnection
    window.RTCPeerConnection = new Proxy(Native, { construct(target, args) {
      const peer = Reflect.construct(target, args)
      window.__smokePeers.push(peer)
      return peer
    } })
  })
  let connected = false
  return {
    revision: publicRevision,
    async login() {
      await page.goto(origin, { waitUntil: 'domcontentloaded', timeout: 30000 })
      if (new URL(page.url()).origin !== origin) throw Error('Unexpected login origin')
      await page.getByLabel('Логин', { exact: true }).fill(credentials.login)
      await page.getByLabel('Пароль', { exact: true }).fill(credentials.password)
      await page.getByRole('button', { name: 'Войти', exact: true }).click()
      await page.getByTestId('app-shell').waitFor({ state: 'visible' })
    },
    async selectEmptyRoom() {
      const expand = page.getByRole('button', { name: 'Развернуть раздел TEST', exact: true })
      if (await expand.isVisible()) await expand.click()
      await page.getByRole('button', { name: credentials.channel, exact: true }).click()
      await page.getByText('Пока никого нет.', { exact: true }).waitFor({ state: 'visible' })
    },
    async connect() {
      await page.getByRole('button', { name: 'Без микрофона', exact: true }).click()
      await page.waitForFunction(() => document.querySelector('[data-testid="voice-dock"] .voice-status')?.textContent?.trim() === 'Голос подключён', null, { timeout: 30000 })
      await page.waitForFunction(() => window.__smokePeers.some(peer => peer.connectionState === 'connected'), null, { timeout: 30000 })
      connected = true
    },
    async publish() {
      const dock = page.getByTestId('voice-dock')
      await dock.getByRole('button', { name: 'Включить микрофон', exact: true }).click()
      await dock.getByRole('button', { name: 'Выключить микрофон', exact: true }).waitFor({ state: 'visible' })
      await page.waitForFunction(() => window.__smokePeers.some(peer =>
        peer.connectionState === 'connected' && peer.getSenders().some(sender =>
          sender.track?.kind === 'audio' && sender.track.readyState === 'live')), null, { timeout: 30000 })
    },
    async disconnect() {
      await page.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала', exact: true }).click()
      await page.getByRole('button', { name: 'Без микрофона', exact: true }).waitFor({ state: 'visible' })
      connected = false
    },
    async logout() {
      await page.getByRole('button', { name: 'Открыть настройки профиля', exact: true }).click()
      await page.getByRole('tab', { name: 'Безопасность', exact: true }).click()
      await page.getByRole('button', { name: 'Выйти из аккаунта', exact: true }).click()
      await page.getByRole('dialog', { name: 'Подтвердите выход из аккаунта' }).getByRole('button', { name: 'Выйти', exact: true }).click()
      await page.locator('.authentication-page').waitFor({ state: 'visible' })
    },
    async close() {
      try {
        if (connected) await page.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала', exact: true }).click()
      } finally { await browser.close() }
    },
  }
}
