import { describe, expect, it } from 'vitest'
import { watch } from 'vue'
import { clearDraftMemory, draftKey, draftMemoryEpoch, loadDraft, saveDraft } from './draft_memory'

describe('authenticated draft epoch', () => {
  it('publishes a synchronous numeric reset without changing the getter contract', () => {
    const before = draftMemoryEpoch(), observed: number[] = []
    const key = draftKey('fixture-account', 'CHANNEL', 'fixture-channel')
    saveDraft(key, { body: 'Private fixture', replyTarget: null, attachments: [], mentionUserIds: [] })
    const duringReset: unknown[] = []
    const stop = watch(() => draftMemoryEpoch(), (value) => { observed.push(value); duringReset.push(loadDraft(key)) }, { flush: 'sync' })
    clearDraftMemory()
    expect(typeof draftMemoryEpoch()).toBe('number')
    expect(draftMemoryEpoch()).toBe(before + 1)
    expect(observed).toEqual([before + 1])
    expect(duringReset).toEqual([null])
    stop()
  })
})
