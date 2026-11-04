import { describe, expect, it, vi } from 'vitest'
import { createHistoryEditorRegistry } from './registry'
import type { EditResult } from '../../message_edit_controller'
const message = { body: 'Original', mentionUserIds: ['peer'], revision: 1 }
function pendingPorts() {
  let finish!: (result: EditResult) => void
  return { finish: (result: EditResult) => finish(result),
    ports: { save: vi.fn(() => new Promise<EditResult>((resolve) => { finish = resolve })),
      refresh: vi.fn().mockResolvedValue({ revision: 2, deleted: false }) } }
}

describe('history editor asynchronous ownership fences', () => {
  it('releases successful pending saves after their MessageItem has unmounted', async () => {
    const registry = createHistoryEditorRegistry(), pending = pendingPorts()
    const binding = registry.bind('first', pending.ports); binding.editor.begin(message)
    binding.editor.body.value = 'Pending draft'; const saving = binding.editor.submit()
    binding.editor.cancel(); expect(registry.size).toBe(1)
    binding.unbind(); pending.finish({ kind: 'saved' }); await saving
    expect(registry.size).toBe(0); expect(binding.editor.editing.value).toBe(false)
  })

  it('preserves pending and conflict state through rebind without duplicate save', async () => {
    const registry = createHistoryEditorRegistry(), pending = pendingPorts()
    const first = registry.bind('first', pending.ports); first.editor.begin(message)
    first.editor.body.value = 'Conflict draft'; const saving = first.editor.submit(); first.unbind()
    const nextPorts = { save: vi.fn().mockResolvedValue({ kind: 'saved' }), refresh: vi.fn().mockResolvedValue({ revision: 2, deleted: false }) }
    const rebound = registry.bind('first', nextPorts)
    expect(rebound.editor.pending.value).toBe(true); await rebound.editor.submit()
    expect(nextPorts.save).not.toHaveBeenCalled()
    pending.finish({ kind: 'conflict', message: 'Conflict fixture' }); await saving
    expect(rebound.editor.body.value).toBe('Conflict draft')
    expect(rebound.editor.needsRefresh.value).toBe(true)
    expect(rebound.editor.error.value).toBe('Conflict fixture')
    await rebound.editor.refreshVersion(); expect(rebound.editor.baseRevision.value).toBe(2)
    await rebound.editor.submit(); expect(nextPorts.save).toHaveBeenCalledWith('Conflict draft', ['peer'], 2)
    expect(registry.size).toBe(0)
  })

  it('clears data synchronously and an old completion cannot delete or repopulate a newer same-ID lease', async () => {
    const registry = createHistoryEditorRegistry(), pending = pendingPorts()
    const old = registry.bind('same', pending.ports); old.editor.begin(message)
    old.editor.body.value = 'Private old draft'; const saving = old.editor.submit()
    registry.clear()
    expect(old.editor.body.value).toBe(''); expect(old.editor.editing.value).toBe(false)
    expect(old.editor.mentionUserIds.value).toEqual([])
    const replacement = registry.bind('same', { save: vi.fn(), refresh: vi.fn() })
    replacement.editor.begin({ ...message, body: 'New account draft' })
    old.unbind(); pending.finish({ kind: 'conflict', message: 'Old result' }); await saving
    expect(registry.size).toBe(1)
    expect(registry.bind('same', { save: vi.fn(), refresh: vi.fn() }).editor).toBe(replacement.editor)
    expect(replacement.editor.body.value).toBe('New account draft')
    expect(old.editor.body.value).toBe(''); expect(old.editor.error.value).toBeNull()
  })
})
