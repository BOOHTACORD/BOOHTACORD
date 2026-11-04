import { describe, expect, it, vi } from 'vitest'
import { createHistoryEditorRegistry, MAX_ACTIVE_HISTORY_EDITS } from './registry'
const message = { body: 'Original', mentionUserIds: ['peer'], revision: 1 }
const ports = () => ({ save: vi.fn().mockResolvedValue({ kind: 'saved' }), refresh: vi.fn().mockResolvedValue({ revision: 2, deleted: false }) })

describe('bounded history editor controller registry', () => {
  it('retains independent controllers across unmount and rebind without retaining old ports', async () => {
    const registry = createHistoryEditorRegistry(), firstPorts = ports(), secondPorts = ports()
    const first = registry.bind('first', firstPorts), second = registry.bind('second', secondPorts)
    first.editor.begin(message); second.editor.begin(message)
    first.editor.body.value = 'First unsaved'; second.editor.body.value = 'Second unsaved'
    first.rememberSelection({ selectionStart: 3, selectionEnd: 8, selectionDirection: 'backward' })
    first.unbind(); second.unbind()
    expect(registry.size).toBe(2)
    const reboundPorts = ports(), rebound = registry.bind('first', reboundPorts)
    expect(rebound.editor).toBe(first.editor)
    expect(rebound.editor.body.value).toBe('First unsaved')
    expect(rebound.editor.mentionUserIds.value).toEqual(['peer'])
    const selection = vi.fn(); rebound.restoreSelection({ setSelectionRange: selection })
    expect(selection).toHaveBeenCalledWith(3, 8, 'backward')
    await rebound.editor.submit()
    expect(firstPorts.save).not.toHaveBeenCalled()
    expect(reboundPorts.save).toHaveBeenCalledWith('First unsaved', ['peer'], 1)
    expect(registry.size).toBe(1)
    const other = registry.bind('second', ports())
    expect(other.editor.body.value).toBe('Second unsaved')
    other.editor.cancel(); expect(registry.size).toBe(0)
  })

  it('caps exactly500 active states without silently evicting any draft and releases a cancelled slot', () => {
    const registry = createHistoryEditorRegistry(), heapBefore = process.memoryUsage().heapUsed
    const bindings = Array.from({ length: MAX_ACTIVE_HISTORY_EDITS }, (_, index) => {
      const binding = registry.bind(String(index), ports())
      binding.editor.begin({ ...message, body: `Draft ${index}` }); return binding
    })
    expect(MAX_ACTIVE_HISTORY_EDITS).toBe(500); expect(registry.size).toBe(500)
    const extra = registry.bind('extra', ports()); extra.editor.begin(message)
    expect(extra.editor.editing.value).toBe(false)
    expect(extra.editor.blockedReason.value).toContain('сохраните или отмените')
    expect(bindings[0]!.editor.body.value).toBe('Draft 0')
    expect(bindings[499]!.editor.body.value).toBe('Draft 499')
    bindings[0]!.editor.cancel(); extra.editor.begin(message)
    expect(extra.editor.editing.value).toBe(true); expect(registry.size).toBe(500)
    console.info(JSON.stringify({ scope: 'native500-active-state observation; noGC or SLO claim', heapBefore,
      heapAfter500: process.memoryUsage().heapUsed, activeStates: registry.size }))
    registry.clear(); expect(registry.size).toBe(0)
    expect(bindings[499]!.editor.body.value).toBe('')
    expect(extra.editor.mentionUserIds.value).toEqual([])
  })

  it('cannot call an unmounted component port and removes all data on disposal', async () => {
    const registry = createHistoryEditorRegistry(), original = ports()
    const binding = registry.bind('first', original); binding.editor.begin(message); binding.unbind()
    await binding.editor.submit(); expect(original.save).not.toHaveBeenCalled()
    expect(binding.editor.body.value).toBe('Original')
    registry.dispose(); binding.editor.begin(message)
    expect(binding.editor.editing.value).toBe(false)
    expect(binding.editor.body.value).toBe(''); expect(registry.size).toBe(0)
  })
})
