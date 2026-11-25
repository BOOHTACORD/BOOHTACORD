import { nextTick, onBeforeUnmount, ref, watch, type Ref } from 'vue'

export function useImageDialog(
  dialog: Ref<HTMLDialogElement | null>, resource: () => string,
  loadPreview: () => Promise<void>, cancelPreview: () => void,
) {
  const trigger = ref<HTMLButtonElement | null>(null)
  const closeButton = ref<HTMLButtonElement | null>(null)
  let opened = false, generation = 0

  function onClosed(): void {
    // A queued close event from a previous opening must not cancel the new one.
    if (dialog.value?.open || !opened) return
    opened = false; generation++
    cancelPreview()
    if (trigger.value?.isConnected) trigger.value.focus()
  }
  function close(): void {
    if (dialog.value?.open) dialog.value.close()
    onClosed()
  }
  async function open(): Promise<void> {
    if (!dialog.value?.isConnected || dialog.value.open) return
    dialog.value.showModal()
    opened = true
    const admitted = ++generation
    await nextTick()
    if (!dialog.value?.open || admitted !== generation) return
    closeButton.value?.focus()
    void loadPreview()
  }
  function onCancel(event: Event): void {
    event.preventDefault()
    close()
  }
  function onDialogClick(event: MouseEvent): void {
    if (event.target !== dialog.value || !dialog.value) return
    const bounds = dialog.value.getBoundingClientRect()
    if (event.clientX < bounds.left || event.clientX > bounds.right ||
        event.clientY < bounds.top || event.clientY > bounds.bottom) close()
  }
  function onKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Tab' || event.altKey || event.ctrlKey || event.metaKey) return
    const items = [...(dialog.value?.querySelectorAll<HTMLElement>(
      'button:not(:disabled), a[href], [tabindex="0"]',
    ) ?? [])].filter(node => node.getClientRects().length)
    const first = items[0], last = items.at(-1)
    if (!first || !last) return
    if ((!event.shiftKey && document.activeElement === last) ||
        (event.shiftKey && document.activeElement === first)) {
      event.preventDefault()
      const target = event.shiftKey ? last : first
      target.focus()
    }
  }
  watch(resource, close, { flush: 'sync' })
  onBeforeUnmount(() => {
    opened = false; generation++
    cancelPreview()
    if (dialog.value?.open) dialog.value.close()
  })
  return { trigger, closeButton, open, close, onCancel, onDialogClick, onClosed, onKeydown }
}
