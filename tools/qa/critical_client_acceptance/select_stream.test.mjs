import { test } from 'node:test'
import assert from 'node:assert/strict'
import { selectVisibleStream } from './select_stream.mjs'

function fixture({ panelOpen = false } = {}) {
  const state = { panelOpen, selected: [] }
  const page = {
    locator(selector) {
      assert.equal(selector, '[data-testid=stream-select]:visible')
      return {
        count: async () => state.panelOpen ? 1 : 0,
        nth(index) {
          return { click: async () => state.selected.push(index) }
        },
      }
    },
    getByRole(role, options) {
      assert.equal(role, 'button')
      assert.equal(options.name.toString(), '/^Трансляции · \\d+$/')
      return { click: async () => { state.panelOpen = true } }
    },
  }
  return { page, state }
}

test('opens the collapsed streams panel before selecting a stream', async () => {
  const { page, state } = fixture()
  await selectVisibleStream(page)
  assert.deepEqual(state, { panelOpen: true, selected: [0] })
})

test('selects from an already open streams panel without toggling it closed', async () => {
  const { page, state } = fixture({ panelOpen: true })
  await selectVisibleStream(page, 1)
  assert.deepEqual(state, { panelOpen: true, selected: [1] })
})
