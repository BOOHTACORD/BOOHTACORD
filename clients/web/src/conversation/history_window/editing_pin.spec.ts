import { computed, effectScope, ref } from 'vue'
import { describe, expect, it } from 'vitest'
import { useEditingPin } from './editing_pin'
import type { HistoryRow } from './window'

interface Row extends HistoryRow { revision: number }
const row = (id: string, revision = 1): Row => ({ key: `message:${id}`, messageId: id,
  kind: 'message', estimate: 96, gap: 12, revision })
function fixture() {
  const scope = effectScope(), rows = ref<Row[]>([row('first'), row('last')])
  const pin = scope.run(() => useEditingPin(computed(() => rows.value), ref<HTMLOListElement | null>(null)))!
  return { scope, rows, pin }
}

describe('single history editing pin lifetime', () => {
  it('does not retain a date row when there is no active editor', () => {
    const { scope, rows, pin } = fixture()
    rows.value = [{ key: 'date', kind: 'date', estimate: 24, gap: 16, revision: 0 }, row('first')]
    expect(pin.row.value).toBeUndefined()
    scope.stop()
  })
  it('retains one keyed row outside the data window and updates it on reattachment', () => {
    const { scope, rows, pin } = fixture()
    pin.setEditing('last', true)
    const original = pin.row.value
    rows.value = [row('older')]
    expect(pin.row.value).toBe(original)
    expect(rows.value.map(({ messageId }) => messageId)).toEqual(['older'])
    rows.value = [row('older'), row('last', 2)]
    expect(pin.row.value?.key).toBe('message:last')
    expect(pin.row.value?.revision).toBe(2)
    expect(rows.value).toHaveLength(2)
    scope.stop()
  })

  it('preserves the existing single-pin replacement and matching-close semantics', () => {
    const { scope, pin } = fixture()
    pin.setEditing('first', true); pin.setEditing('last', true)
    pin.setEditing('first', false)
    expect(pin.row.value?.messageId).toBe('last')
    pin.setEditing('last', false)
    expect(pin.row.value).toBeUndefined()
    scope.stop()
  })

  it('does not drop the retained VNode when its already-detached editor receives focus', () => {
    const { scope, rows, pin } = fixture()
    pin.setEditing('last', true); const retained = pin.row.value
    rows.value = [row('older')]; pin.setEditing('last', true)
    expect(pin.row.value).toBe(retained)
    scope.stop()
  })

  it('clears an evicted row explicitly without adding it to an empty data window', () => {
    const { scope, rows, pin } = fixture()
    pin.setEditing('last', true); rows.value = []
    pin.clear()
    expect(pin.row.value).toBeUndefined()
    expect(rows.value).toEqual([])
    scope.stop()
  })

  it('releases the retained row when its component scope is disposed', () => {
    const { scope, rows, pin } = fixture()
    pin.setEditing('last', true); rows.value = [row('older')]
    scope.stop()
    expect(pin.row.value).toBeUndefined()
  })
})
