import { randomUUID } from 'node:crypto'
import assert from 'node:assert/strict'
import { api, expect, openNavigation, status } from '../client_lifecycle/request.mjs'
import { editingAcceptance } from './editing.mjs'
import { historyProfiles } from './profiles.mjs'
import { seedHistory, validateMessageIdentifiers } from './seed.mjs'

export async function historyAcceptance(a, b, input, report) {
  const owner = process.env.QA_DB_OWNER
  const category = await api(a, '/admin/categories', 'POST', { name: 'HistoryAcceptance' })
  status(category, 201)
  const created = await api(a, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'HistoryLab', kind: 'TEXT' })
  status(created, 201)
  seedHistory(owner, created.body.id, 1000, 50)
  const seeded = await api(a, `/channels/${created.body.id}/messages`)
  status(seeded, 200); assert.equal(seeded.body.messages.length, 50)
  validateMessageIdentifiers(seeded.body.messages)
  // A newly created first channel can open before SQL fixture insertion emits any hint.
  // Start the scenario from a cold protected read; no reload occurs during the edit roundtrip.
  await a.reload(); await expect(a.getByTestId('app-shell')).toBeVisible()
  await openNavigation(a)
  await expect(a.getByRole('img', { name: 'В сети', exact: true })).toBeVisible()
  const result = { width: input.viewport.width, mocks: false, fixture_rows: 1000 }
  await editingAcceptance(a, b, created.body.id, input.directory, result)
  if (input.history_matrix) {
    const foreign = await api(a, `/channels/${created.body.id}/messages`, 'POST', {
      client_message_id: randomUUID(), body: 'Synthetic cross-scope reference fixture',
    })
    status(foreign, 201)
    result.profiles = await historyProfiles(a, category.body.id, foreign.body.id, owner)
  }
  report.history_edit_retention = result
}
