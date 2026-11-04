import { ref } from 'vue'
import { EditorEntry, type EditPorts, type EntryOwner } from './entry'
export const MAX_ACTIVE_HISTORY_EDITS = 500
export function createHistoryEditorRegistry() {
  const entries = new Map<string, EditorEntry>(), changed = ref(0)
  let generation = 0, disposed = false
  const owner: EntryOwner = {
    valid: (entry) => !disposed && entry.generation === generation,
    reserve: (entry) => {
      if (!owner.valid(entry)) return false
      const current = entries.get(entry.id)
      if (current) return current === entry
      if (entries.size >= MAX_ACTIVE_HISTORY_EDITS) return false
      entries.set(entry.id, entry); changed.value++; return true
    },
    release: (entry) => { if (entries.get(entry.id) === entry) { entries.delete(entry.id); changed.value++ } },
  }
  function clear(): void {
    generation++
    const previous = [...entries.values()]; entries.clear(); changed.value++
    for (const entry of previous) entry.wipe()
  }
  return {
    get size() { return entries.size },
    has: (id: string) => { changed.value; return entries.has(id) },
    bind: (id: string, ports: EditPorts) => (entries.get(id) ?? new EditorEntry(id, generation, owner)).bind(ports),
    clear,
    dispose: () => { disposed = true; clear() },
  }
}
export type HistoryEditorRegistry = ReturnType<typeof createHistoryEditorRegistry>
