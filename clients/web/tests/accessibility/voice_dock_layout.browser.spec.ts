import { expect, test } from '@playwright/test'

test('voice dock action row fills desktop and open mobile drawer evenly', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
    const { default: VoiceDock } = await import('/src/voice/VoiceDock.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const channel = { id: 'voice-1', name: 'Комната', kind: 'VOICE', position: 0, admissionClosed: false }
    createApp({ render: () => h('aside', { class: 'sidebar', style: 'width:280px' }, [
      h(VoiceDock, {
        class: 'mobile-voice-dock', channel, activeSession: true, error: null,
        activationMode: 'VAD', deafened: false, deafenChanging: false,
        microphoneMuted: false, microphonePermissionDenied: false,
        screenShareState: 'IDLE', state: 'CONNECTED',
      }),
    ]) }).mount('#mount')
  })

  const dock = page.locator('.mobile-voice-dock')
  const row = dock.locator('.voice-actions')
  const buttons = row.locator('.voice-icon-button')
  await expect(dock).toBeVisible()
  await expect(buttons).toHaveCount(4)

  const measure = () => page.evaluate(() => {
    const dock = document.querySelector<HTMLElement>('.mobile-voice-dock')!
    const row = dock.querySelector<HTMLElement>('.voice-actions')!
    const buttons = [...row.querySelectorAll<HTMLElement>('.voice-icon-button')]
    const rect = (element: Element) => {
      const { x, y, width, height } = element.getBoundingClientRect()
      return { x, y, width, height }
    }
    return {
      dock: rect(dock),
      row: rect(row),
      buttons: buttons.map(rect),
      icons: buttons.map(button => rect(button.querySelector('svg')!)),
    }
  })
  const expectEvenRow = (geometry: Awaited<ReturnType<typeof measure>>, minHeight: number) => {
    const widths = geometry.buttons.map(button => button.width)
    expect(Math.max(...widths) - Math.min(...widths)).toBeLessThanOrEqual(1)
    expect(geometry.row.width).toBeGreaterThanOrEqual(geometry.dock.width - 40)
    expect(geometry.buttons[0].x).toBeGreaterThanOrEqual(geometry.row.x - 3)
    expect(geometry.buttons.at(-1)!.x + geometry.buttons.at(-1)!.width).toBeLessThanOrEqual(geometry.row.x + geometry.row.width + 3)
    for (const button of geometry.buttons) expect(button.height).toBeGreaterThanOrEqual(minHeight)
    for (const icon of geometry.icons) {
      expect(icon.width).toBe(20)
      expect(icon.height).toBe(20)
    }
  }

  const desktop = await measure()
  expectEvenRow(desktop, 40)
  await page.screenshot({ path: testInfo.outputPath('voice-dock-width-desktop.png') })
  await page.locator('.sidebar').evaluate(element => element.classList.add('is-open'))
  await page.setViewportSize({ width: 390, height: 844 })
  await expect(dock).toBeVisible()
  const mobile = await measure()
  expectEvenRow(mobile, 44)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await page.screenshot({ path: testInfo.outputPath('voice-dock-width-mobile.png') })
  console.info(`voice-dock-width-geometry=${JSON.stringify({ desktop, mobile })}`)
})
