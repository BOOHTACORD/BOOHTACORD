import { test } from 'node:test'
import assert from 'node:assert/strict'
import { openViewerPanel, selectVisibleStream } from './select_stream.mjs'

function fixture({ panel = null, previewCount = 0 } = {}) {
  const state = { panel, previewCount, previewSelected: [], selected: [] }
  const page = {
    locator(selector) {
      assert.ok(['[data-testid=participant-screen-preview]:visible', '[data-testid=stream-select]:visible', '[data-testid=viewer-participants]:visible'].includes(selector))
      return {
        count: async () => selector === '[data-testid=participant-screen-preview]:visible' ? state.previewCount
          : (state.panel === 'streams' && selector === '[data-testid=stream-select]:visible')
          || (state.panel === 'participants' && selector === '[data-testid=viewer-participants]:visible') ? 1 : 0,
        nth(index) {
          return { click: async () => (selector === '[data-testid=participant-screen-preview]:visible' ? state.previewSelected : state.selected).push(index) }
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
  assert.deepEqual(state, { panel: 'streams', previewCount: 0, previewSelected: [], selected: [0] })
})

test('selects from an already open streams panel without toggling it closed', async () => {
  const { page, state } = fixture({ panel: 'streams' })
  await selectVisibleStream(page, 1)
  assert.deepEqual(state, { panel: 'streams', previewCount: 0, previewSelected: [], selected: [1] })
})

test('opens a stream from its participant card before using the stream selector', async () => {
  const { page, state } = fixture({ panel: 'participants', previewCount: 2 })
  await selectVisibleStream(page, 1)
  assert.deepEqual(state, { panel: 'participants', previewCount: 2, previewSelected: [1], selected: [] })
})

test('opens the collapsed participants panel and leaves an open panel untouched', async () => {
  const collapsed = fixture()
  await openViewerPanel(collapsed.page, 'participants')
  assert.equal(collapsed.state.panel, 'participants')

  const expanded = fixture({ panel: 'participants' })
  await openViewerPanel(expanded.page, 'participants')
  assert.equal(expanded.state.panel, 'participants')
})
