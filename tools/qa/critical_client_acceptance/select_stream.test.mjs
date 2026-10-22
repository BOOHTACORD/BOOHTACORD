import { test } from 'node:test'
import assert from 'node:assert/strict'
import { openViewerPanel, selectVisibleStream } from './select_stream.mjs'

function fixture({ panel = null } = {}) {
  const state = { panel, selected: [] }
  const page = {
    locator(selector) {
      assert.ok(['[data-testid=stream-select]:visible', '[data-testid=viewer-participants]:visible'].includes(selector))
      return {
        count: async () => (state.panel === 'streams' && selector === '[data-testid=stream-select]:visible')
          || (state.panel === 'participants' && selector === '[data-testid=viewer-participants]:visible') ? 1 : 0,
        nth(index) {
          return { click: async () => state.selected.push(index) }
        },
      }
    },
    getByRole(role, options) {
      assert.equal(role, 'button')
      const panel = options.name.test('Трансляции · 2') ? 'streams'
        : options.name.test('Участники · 3 · Зрители · 1') ? 'participants' : null
      assert.ok(panel, 'the panel button must use its accessible label')
      return { click: async () => { state.panel = panel } }
    },
  }
  return { page, state }
}

test('opens the collapsed streams panel before selecting a stream', async () => {
  const { page, state } = fixture()
  await selectVisibleStream(page)
  assert.deepEqual(state, { panel: 'streams', selected: [0] })
})

test('selects from an already open streams panel without toggling it closed', async () => {
  const { page, state } = fixture({ panel: 'streams' })
  await selectVisibleStream(page, 1)
  assert.deepEqual(state, { panel: 'streams', selected: [1] })
})

test('opens the collapsed participants panel and leaves an open panel untouched', async () => {
  const collapsed = fixture()
  await openViewerPanel(collapsed.page, 'participants')
  assert.equal(collapsed.state.panel, 'participants')

  const expanded = fixture({ panel: 'participants' })
  await openViewerPanel(expanded.page, 'participants')
  assert.equal(expanded.state.panel, 'participants')
})
