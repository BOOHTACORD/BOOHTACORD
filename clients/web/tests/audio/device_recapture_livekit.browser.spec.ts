import { expect, test } from '@playwright/test'
import { closeInputs, inputGate, inputReady } from './input_lifecycle/steps'

test('a replacement capture keeps the chosen device audible through LiveKit', async ({ browser }) => {
  const senderContext = await browser.newContext(), receiverContext = await browser.newContext()
  const sender = await senderContext.newPage(), receiver = await receiverContext.newPage()
  let failed = false
  const hear = async (frequency: number) => expect.poll(async () => {
    const sample = await inputGate(receiver, 'sample')
    return sample.rms > 0.01 && sample.nonfinite === 0 && Math.abs(sample.frequency - frequency) < 30
  }, { timeout: 15000 }).toBe(true)
  try {
    await sender.route('**/api/v1/auth/session', route => route.fulfill({ json: { account_id: 'qa-account', role: 'MEMBER' } }))
    for (const page of [sender, receiver]) { await page.goto('/tests/audio/fixture.html'); await inputReady(page) }
    await inputGate(sender, 'mount', ['off'])
    await inputGate(receiver, 'receiver')
    await inputGate(sender, 'join')
    await hear(440)
    await inputGate(sender, 'ignoreNextConstraint')
    const selector = sender.getByRole('combobox', { name: 'Микрофон', exact: true })
    await selector.selectOption('mic-2')
    await expect(selector).toHaveValue('mic-2')
    await expect(selector).toBeEnabled()
    await hear(880)
    const result = await inputGate(sender, 'read')
    expect(result.selected).toBe('mic-2')
    expect(result.captures.map((capture: any) => capture.deviceId)).toEqual(['mic-1', 'mic-2', 'mic-2'])
    const before = (await inputGate(receiver, 'read')).receivedSubscriptions
    await inputGate(sender, 'ignoreNextConstraint')
    await inputGate(sender, 'reconnect')
    await expect.poll(async () => (await inputGate(sender, 'read')).captures.length, { timeout: 15000 }).toBeGreaterThanOrEqual(5)
    await expect.poll(async () => (await inputGate(receiver, 'read')).receivedSubscriptions, { timeout: 15000 }).toBeGreaterThan(before)
    await hear(880)
    const restored = await inputGate(sender, 'read')
    expect(restored).toMatchObject({ selected: 'mic-2', publications: 1 })
    expect(restored.captures.at(-1).deviceId).toBe('mic-2')
  } catch (error) { failed = true; throw error }
  finally { await closeInputs([sender, receiver], [senderContext, receiverContext], failed) }
})
