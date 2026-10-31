import { ref } from 'vue'
import { useMessageEditController, type EditResult } from '../../message_edit_controller'
export type EditPorts = Parameters<typeof useMessageEditController>[0]
export interface EntryOwner { valid(entry: EditorEntry): boolean; reserve(entry: EditorEntry): boolean; release(entry: EditorEntry): void }
type Selection = { start: number; end: number; direction: 'forward' | 'backward' | 'none' }
type SelectionInput = Pick<HTMLTextAreaElement, 'selectionStart' | 'selectionEnd' | 'selectionDirection'>
type SelectionOutput = Pick<HTMLTextAreaElement, 'setSelectionRange'>
const unavailable: EditResult = { kind: 'stale', message: 'Сообщение недоступно.' }

export class EditorEntry {
  private ports: EditPorts | null = null
  private token: symbol | null = null
  private selection: Selection | null = null
  readonly state
  readonly editor
  constructor(readonly id: string, readonly generation: number, private readonly owner: EntryOwner) {
    this.state = useMessageEditController({
      save: (...args) => owner.valid(this) && this.ports ? this.ports.save(...args) : Promise.resolve(unavailable),
      refresh: () => owner.valid(this) && this.ports ? this.ports.refresh() : Promise.resolve(null),
    })
    const state = this.state, blockedReason = ref<string | null>(null)
    const run = async (action: () => Promise<void>): Promise<void> => {
      if (!owner.valid(this)) { this.wipe(); return }
      await action()
      if (!owner.valid(this)) this.wipe()
      else if (!state.editing.value) owner.release(this)
    }
    this.editor = { ...state, blockedReason,
      begin: (message: Parameters<typeof state.begin>[0]) => {
        if (!owner.valid(this)) { this.wipe(); return }
        if (!owner.reserve(this)) { blockedReason.value = 'Сначала сохраните или отмените одно из открытых редактирований.'; return }
        blockedReason.value = null; state.begin(message)
      },
      cancel: () => {
        if (!owner.valid(this)) { this.wipe(); return }
        state.cancel(); if (!state.editing.value) owner.release(this)
      },
      submit: () => run(state.submit), refreshVersion: () => run(state.refreshVersion),
    }
  }
  wipe(): void {
    const state = this.state
    this.ports = null; this.token = null; this.selection = null
    state.editing.value = false; state.body.value = ''; state.mentionUserIds.value = []
    state.baseRevision.value = 0; state.pending.value = false; state.needsRefresh.value = false
    state.error.value = null; state.notice.value = null; this.editor.blockedReason.value = null
  }
  bind(ports: EditPorts) {
    const token = Symbol('mounted-editor'); this.ports = ports; this.token = token
    const current = () => this.owner.valid(this) && this.token === token
    return { editor: this.editor,
      unbind: () => { if (this.token === token) { this.ports = null; this.token = null } },
      rememberSelection: (input: SelectionInput | null) => {
        if (current() && this.state.editing.value && input) this.selection = {
          start: input.selectionStart, end: input.selectionEnd, direction: input.selectionDirection }
      },
      restoreSelection: (input: SelectionOutput | null) => {
        if (current() && this.state.editing.value && input && this.selection)
          input.setSelectionRange(this.selection.start, this.selection.end, this.selection.direction)
      },
    }
  }
}
