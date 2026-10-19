import assert from 'node:assert/strict'

// Unread acceptance deliberately persists an old scroll context. Navigation must
// start from its own never-opened scope, without erasing that earlier evidence.
export async function navigationFixture(previous, createChannel, seed, establishCursor) {
  const id=await createChannel()
  assert.ok(id && id!==previous.a,'Navigation must own a fresh conversation scope')
  const fixture={...previous,a:id}
  const history=seed(fixture,'CHANNEL')
  assert.equal(history.ids.length,121,'Original navigation history coverage required')
  assert.equal(new Set(history.ids).size,121,'Unique real fixture rows required')
  const latest=history.ids.at(-1)
  assert.equal(await establishCursor(fixture,latest),latest,'Navigation requires a real initial read baseline')
  return fixture
}
