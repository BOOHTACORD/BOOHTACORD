import { expect, test, type Page } from '@playwright/test'

import { closeInputs, inputGate, inputReady as ready } from './input_lifecycle/steps'
async function choose(page: Page, id: string) {
  const selector = page.getByRole('combobox', { name: 'Микрофон', exact: true })
  await selector.selectOption(id)
  await expect(selector).toHaveValue(id)
  await expect(selector).toBeEnabled()
}
async function hear(page: Page, frequency: number) {
  await expect.poll(async () => {
    const sample = await inputGate(page, 'sample')
    return sample.rms > 0.01 && sample.nonfinite === 0 && Math.abs(sample.frequency - frequency) < 30
  }, { timeout: 15000 }).toBe(true)
}
async function silence(page: Page) {
  await expect.poll(async () => (await inputGate(page, 'sample')).rms, { timeout: 15000 }).toBeLessThan(0.001)
}

for (const mode of ['off', 'browser', 'rnnoise'] as const) {
  test(`selected input reaches a real peer without a probe and survives mute/reconnect (${mode})`, async ({ browser }) => {
    const senderContext = await browser.newContext(), receiverContext = await browser.newContext()
    const sender = await senderContext.newPage(), receiver = await receiverContext.newPage()
    let hadFailure = false
    const deafenWrites: boolean[] = []
    try {
      await sender.route('**/api/v1/auth/session', route => route.fulfill({ json: { account_id: 'qa-account', role: 'MEMBER' } }))
      await sender.route('**/api/v1/voice/leases/*/deafen/v1', async route => {
        expect(route.request().method()).toBe('PUT')
        deafenWrites.push(route.request().postDataJSON().deafened)
        await route.fulfill({ status: 204 })
      })
      if (mode === 'rnnoise') await sender.route('**/audio/rnnoise/**', route => route.fulfill({ status: 404, body: 'Synthetic asset fallback' }))
      await sender.goto('/tests/audio/fixture.html'); await receiver.goto('/tests/audio/fixture.html')
      await Promise.all([ready(sender), ready(receiver)])
      await inputGate(sender, 'mount', [mode])
      await choose(sender, 'mic-2')
      expect((await inputGate(sender, 'read')).captures).toEqual([])
      await inputGate(receiver, 'receiver')
      const joined = await inputGate(sender, 'join')
      expect(joined.captures[0].deviceId).toBe('mic-2')
      expect(joined.ownedCapture).toBe(true)
      await hear(receiver, 880)
      await choose(sender, 'mic-1'); await hear(receiver, 440)
      await sender.getByRole('button', { name: 'Проверить микрофон', exact: true }).click()
      await expect(sender.getByRole('button', { name: 'Остановить проверку микрофона' })).toBeVisible()
      const before = await inputGate(sender, 'read')
      await sender.getByRole('button', { name: 'Остановить проверку микрофона' }).click()
      expect((await inputGate(sender, 'read')).captures).toEqual(before.captures)
      await inputGate(sender, 'mute')
      await silence(receiver)
      await choose(sender, 'mic-2'); await silence(receiver)
      expect((await inputGate(sender, 'read')).enabled).toBe(false)
      await inputGate(sender, 'reconnect')
      await expect.poll(async () => (await inputGate(sender, 'read')).captures.length).toBeGreaterThan(before.captures.length + 1)
      await silence(receiver)
      expect((await inputGate(sender, 'read')).selected).toBe('mic-2')
      await inputGate(sender, 'mute', [false]); await hear(receiver, 880)
      await inputGate(sender, 'deafen', [true])
      await choose(sender, 'mic-1'); await silence(receiver)
      await inputGate(sender, 'deafen', [false]); await hear(receiver, 440)
      expect(deafenWrites).toEqual([true, false])
      await inputGate(sender, 'unplug', ['mic-1'])
      await expect(sender.getByText(/Используется системный микрофон|Сохранён предыдущий источник|Микрофон недоступен/)).toBeVisible()
      await hear(receiver, 880)
      await inputGate(sender, 'removeAll')
      await expect(sender.getByRole('status').filter({ hasText: /Микрофон недоступен. Отправка звука выключена/ })).toBeVisible()
      await silence(receiver)
    } catch (error) {
      hadFailure = true
      throw error
    } finally {
      await closeInputs([sender, receiver], [senderContext, receiverContext], hadFailure)
    }
  })
}

test('prejoin probe and reload do not select a different call source; listener selection never captures', async ({ page }) => {
  await page.route('**/api/v1/auth/session', route => route.fulfill({ json: { account_id: 'qa-account', role: 'MEMBER' } }))
  await page.goto('/tests/audio/fixture.html')
  await ready(page)
  await inputGate(page, 'mount')
  await choose(page, 'mic-2')
  await page.getByRole('button', { name: 'Проверить микрофон', exact: true }).click()
  await expect(page.getByRole('button', { name: 'Остановить проверку микрофона' })).toBeVisible()
  await page.getByRole('button', { name: 'Остановить проверку микрофона' }).click()
  const before = await inputGate(page, 'read')
  expect(before.selected).toBe('mic-2')
  expect(before.captures[0]).toEqual({ deviceId: 'mic-2', ended: true })
  await inputGate(page, 'stop')
  await page.reload()
  await ready(page)
  await inputGate(page, 'mount')
  await expect(page.getByRole('combobox', { name: 'Микрофон', exact: true })).toHaveValue('mic-2')
  await inputGate(page, 'join', ['listener'])
  await choose(page, 'mic-1')
  expect((await inputGate(page, 'read')).captures).toEqual([])
  await inputGate(page, 'mute', [false])
  expect((await inputGate(page, 'read')).captures[0].deviceId).toBe('mic-1')
  await inputGate(page, 'stop')
})
