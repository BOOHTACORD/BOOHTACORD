import { expect, test } from '@playwright/test'
import { chatMembers, chatProfile, chatTopology } from '../../artifacts/design-v2/chat-reference-fixture.mjs'
import { installReferenceTransports } from '../../artifacts/design-v2/reference-live-state.mjs'

test.beforeEach(async ({ page }) => {
  await installReferenceTransports(page)
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname
    let body: unknown = {}
    if (path.endsWith('/auth/session')) body = { account_id: chatProfile.account_id, role: chatProfile.role }
    else if (path.endsWith('/auth/permissions')) body = { account_id: chatProfile.account_id, role: chatProfile.role, permissions_revision: 1, permissions: {} }
    else if (path.endsWith('/channels')) body = chatTopology
    else if (path.endsWith('/me')) body = chatProfile
    else if (path.endsWith('/members')) body = { members: chatMembers }
    else if (path.includes('/members/')) body = chatMembers.find(member => path.endsWith(`/${member.user_id}`)) ?? {}
    else if (path.endsWith('/direct-messages')) body = { direct_messages: [{ id: 'dm-daria', other_participant_id: 'daria-2', other_participant_display_name: 'Daria', created_at: '2026-10-03T10:00:00Z', unread_count: 0, mention_count: 0 }] }
    else if (path.includes('/messages')) body = { messages: [] }
    else if (path.includes('/read-cursor')) body = { message_id: null }
    else if (path.includes('/maintenance')) body = { active: false }
    else if (path.includes('/client-updates')) body = { state: 'unconfigured', target: null }
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
  })
})

for (const kind of ['CHANNEL', 'DM']) for (const width of [320, 393, 1024, 1280, 1440]) for (const scale of [1, 2]) {
  test(`${kind} composer fits one full line at ${width}px and ${scale * 100}% text`, async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 })
    await page.goto('/')
    await expect(page.locator('#message-body')).toBeVisible()
    if (kind === 'DM') {
      await page.getByRole('button', { name: 'Личные', exact: true }).click()
      await page.locator('.direct-message-navigation .channel-button').filter({ hasText: 'Daria' }).click()
    }
    await page.setViewportSize({ width, height: 900 })
    await page.evaluate(async scale => { document.documentElement.style.fontSize = `${scale * 100}%`; await document.fonts.ready }, scale)
    const field = page.locator(kind === 'CHANNEL' ? '#message-body' : '#direct-message-body')
    const empty = await field.evaluate(element => {
      const field = element as HTMLTextAreaElement, css = getComputedStyle(field), rect = field.getBoundingClientRect()
      return { contentHeight: field.clientHeight - parseFloat(css.paddingTop) - parseFloat(css.paddingBottom), lineHeight: parseFloat(css.lineHeight), bottom: rect.bottom, formBottom: field.closest('form')!.getBoundingClientRect().bottom, viewportBottom: innerHeight }
    })
    expect(empty.contentHeight).toBeGreaterThanOrEqual(empty.lineHeight - 0.5)
    expect(empty.bottom).toBeLessThanOrEqual(empty.formBottom + 0.5)
    expect(empty.formBottom).toBeLessThanOrEqual(empty.viewportBottom + 0.5)
    await field.fill('Synthetic')
    const singleLine = await field.evaluate(element => { const field = element as HTMLTextAreaElement; return { scrollHeight: field.scrollHeight, clientHeight: field.clientHeight, scrollTop: field.scrollTop } })
    expect(singleLine.scrollHeight).toBeLessThanOrEqual(singleLine.clientHeight + 1)
    expect(singleLine.scrollTop).toBe(0)
    await field.press('Shift+Enter')
    await field.press('KeyX')
    await expect(field).toHaveValue('Synthetic\nx')
    await expect(field).toBeFocused()
    const multiline = await field.evaluate(element => { const field = element as HTMLTextAreaElement; return { scrollHeight: field.scrollHeight, clientHeight: field.clientHeight, scrollTop: field.scrollTop } })
    expect(multiline.scrollHeight).toBeGreaterThan(multiline.clientHeight)
    expect(multiline.scrollTop).toBeGreaterThan(0)
  })
}
