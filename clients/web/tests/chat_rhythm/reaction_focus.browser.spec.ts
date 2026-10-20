import { test, expect } from '@playwright/test'
import { kinds, mount, row } from './helpers'
import { createResponseGate } from '../settings_hierarchy/response_gate'

for (const kind of kinds) for (const moveFocus of [false, true]) {
  test(`${kind} pending reaction preserves keyboard focus without stealing it (move=${moveFocus})`, async ({ page }) => {
    const commands = await mount(page, kind)
    const gate = createResponseGate()
    let mutations = 0
    await page.route('**/reactions/**', async route => {
      mutations++
      await gate.hold()
      await route.fallback()
    })
    const tools = row(page, 1).getByRole('group', { name: 'Реакции на сообщение', exact: true })
    const summary = tools.locator('summary')
    await summary.focus()
    await summary.press('Enter')
    const like = tools.locator('.reaction-palette').getByRole('button', { name: 'Реакция 👍', exact: true })
    await like.focus()
    await like.press('Enter')
    await expect(like).toBeDisabled()
    await expect(like).toBeFocused()
    // Repeated keyboard activation while pending must not send a second mutation.
    await like.press('Enter')
    if (moveFocus) await summary.focus()
    await gate.releaseNext()
    await expect(like).toBeEnabled()
    await expect(tools.locator('.reaction-counts button')).toHaveAttribute('aria-pressed', 'true')
    await expect(moveFocus ? summary : like).toBeFocused()
    expect(mutations).toBe(1)
    expect(commands.filter(command => command.path.includes('/reactions/')).map(command => command.method)).toEqual(['PUT'])
  })
}
