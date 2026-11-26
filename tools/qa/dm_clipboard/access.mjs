import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { api, status, expect } from '../client_lifecycle/request.mjs'
export async function probe(page, path, upload = false) {
  return page.evaluate(async ({ path, upload }) => {
    let body
    if (upload) { body = new FormData(); body.append('file', new File(['bounded fixture'], 'denied.txt')) }
    const response = await fetch('/api/v1'+path, { method: upload ? 'POST' : 'GET', credentials: 'same-origin', ...(body ? { body } : {}) })
    const bytes = new Uint8Array(await response.arrayBuffer())
    const hash = response.ok ? [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))].map(n => n.toString(16).padStart(2, '0')).join('') : null
    return { status: response.status, size: bytes.length, hash, type: response.headers.get('content-type'),
      disposition: response.headers.get('content-disposition'), nosniff: response.headers.get('x-content-type-options') }
  }, { path, upload })
}
export async function verifyAccess(owner, peer, outsider, admin, fixture, message, hash) {
  const prefix = '/direct-messages/'+fixture.a, attachment = message.attachments[0].id
  const original = await probe(peer, prefix+'/attachments/'+attachment)
  assert.equal(original.status, 200); assert.equal(original.hash, hash); assert.match(original.disposition, /^attachment;/)
  assert.equal(original.nosniff, 'nosniff')
  const preview = await probe(peer, prefix+'/attachments/'+attachment+'/preview')
  assert.equal(preview.status, 200); assert.ok(preview.size > 0); assert.match(preview.type, /^image\/png/)
  assert.equal(preview.nosniff, 'nosniff')
  await expect(peer.locator(`[data-message-id="${message.id}"]`)).toBeVisible()
  for (const actor of [outsider, admin]) {
    for (const suffix of ['/messages?limit=20','/search?query=fixture','/attachments/'+attachment,'/attachments/'+attachment+'/preview']) {
      assert.equal((await probe(actor, prefix+suffix)).status, 404)
    }
    assert.ok([403,404].includes((await probe(actor, prefix+'/attachments', true)).status))
  }
  const crossing = await api(owner, '/direct-messages/'+fixture.b+'/messages', 'POST', {
    client_message_id: randomUUID(), body: 'cross-scope fixture', attachment_ids: [attachment],
  })
  assert.ok([400,404].includes(crossing.status))
  const history = await api(owner, '/direct-messages/'+fixture.b+'/messages?limit=20'); status(history, 200)
  assert.equal(history.body.messages.length, 0)
}
