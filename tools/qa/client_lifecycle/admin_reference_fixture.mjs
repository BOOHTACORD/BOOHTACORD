import assert from 'node:assert/strict'
import { api, status } from './request.mjs'

async function category(admin, name) {
  const result = await api(admin, '/admin/categories', 'POST', { name })
  status(result, 201)
  return result.body.id
}

async function channel(admin, categoryId, name, kind) {
  const result = await api(admin, `/admin/categories/${categoryId}/channels`, 'POST', { name, kind })
  status(result, 201)
  return result.body
}

export async function seedAdminReferenceTopology(admin) {
  const general = await category(admin, 'General')
  await channel(admin, general, 'Voice', 'VOICE')
  await channel(admin, general, 'Голос', 'VOICE')
  const welcome = await channel(admin, general, 'Text', 'TEXT')
  const log = await channel(admin, general, 'log', 'TEXT')

  const test = await category(admin, 'TEST')
  await channel(admin, test, 'SHARE_TEST', 'VOICE')

  const voice = await category(admin, 'Голосовой раздел')
  for (const name of ['Канал №1', 'Канал №2', 'Канал №3']) {
    await channel(admin, voice, name, 'VOICE')
  }
  return { welcome, log }
}

export async function seedAdminAuditHistory(admin) {
  const initial = await api(admin, '/admin/guild-settings')
  status(initial, 200)
  const expectedName = 'Автономная гильдия'
  assert.equal(initial.body.name, expectedName)

  let name = initial.body.name
  let revision = initial.body.revision
  for (let index = 0; index < 90; index++) {
    name = name === expectedName ? 'Автономная гильдия QA' : expectedName
    const result = await api(admin, '/admin/guild-settings', 'PATCH', {
      name,
      expected_revision: revision,
    })
    status(result, 200)
    name = result.body.name
    revision = result.body.revision
  }
  assert.equal(name, expectedName)
  return revision
}
