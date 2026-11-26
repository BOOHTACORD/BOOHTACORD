import assert from 'node:assert/strict'
import { api, status, expect, openNavigation } from '../client_lifecycle/request.mjs'
export const selector = '#direct-message-body'
export async function setup(admin, password, width, shared) {
  const members = []
  for (const suffix of (shared ? ['sender'] : ['sender', 'peer', 'other'])) {
    const login = `qa_dm_${suffix}_${width}`, created = await api(admin, '/auth/register', 'POST', { login, password })
    status(created, 201); assert.ok(created.body.id)
    members.push({ login, id: created.body.id, name: created.body.display_name })
  }
  const category = await api(admin, '/admin/categories', 'POST', { name: 'DMReservation'+width }); status(category, 201)
  const room = await api(admin, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'DMReservation'+width, kind: 'TEXT' }); status(room, 201)
  return { owner: members[0], peer: shared?.peer ?? members[1], other: shared?.other ?? members[2], channel: room.body.id }
}
export async function dialogs(owner, fixture) {
  const result = []
  for (const member of [fixture.peer, fixture.other]) {
    const opened = await api(owner, '/direct-messages', 'POST', { participant_id: member.id }); status(opened, 201)
    assert.ok(opened.body.id); result.push(opened.body.id)
  }
  await owner.reload(); await expect(owner.getByTestId('app-shell')).toBeVisible()
  return { ...fixture, a: result[0], b: result[1] }
}
export async function openDM(page, name) {
  await openNavigation(page)
  await page.getByRole('button', { name: 'Личные', exact: true }).click()
  await page.locator('.direct-message-navigation .channel-button').filter({ has: page.getByText(name, { exact: true }) }).click()
  await expect(page.locator('#direct-message-title')).toHaveText(name)
  await expect(page.locator(selector)).toBeEnabled()
}
