import { inject, onBeforeUnmount, provide, ref, watch, type InjectionKey, type Ref } from 'vue'
import { useMessageEditController } from '../../message_edit_controller'
import { createHistoryEditorRegistry, type HistoryEditorRegistry } from './registry'
import type { EditPorts } from './entry'
export type { EditResult } from '../../message_edit_controller'
const key: InjectionKey<HistoryEditorRegistry> = Symbol('text-history-editors')
export function provideHistoryEditors() {
  const registry = createHistoryEditorRegistry(); provide(key, registry); return registry
}
export function useHistoryMessageEditor(id: string, ports: EditPorts, input: Ref<HTMLTextAreaElement | null>) {
  const registry = inject(key, null)
  if (!registry) return { ...useMessageEditController(ports), blockedReason: ref<string | null>(null) }
  const binding = registry.bind(id, ports)
  watch(input, (element, _previous, cleanup) => {
    if (!element) return
    binding.restoreSelection(element)
    const remember = () => binding.rememberSelection(element)
    element.addEventListener('select', remember); element.addEventListener('blur', remember)
    cleanup(() => { remember(); element.removeEventListener('select', remember); element.removeEventListener('blur', remember) })
  }, { flush: 'post' })
  onBeforeUnmount(() => { binding.rememberSelection(input.value); binding.unbind() })
  return binding.editor
}
