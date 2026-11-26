import { computed, ref, shallowRef } from 'vue'
import { MAX_MESSAGE_ATTACHMENTS } from '../attachment_limits'
import { drain } from './runner'
import { uploadFailureMessage } from './failure'
import type { Emit, Item, Prepared, State, Upload } from './types'

export function createManagedUploadQueue<T extends Prepared>(scope: () => string, disabled: () => boolean,
  emit: Emit<T>, uploadFile: Upload<T>, initial: T[] = []) {
  let sequence = 0
  const items = shallowRef<Item<T>[]>([]), error = ref<string | null>(null)
  const attachments = computed(() => items.value.flatMap(item => item.attachment ? [item.attachment] : []))
  const failed = computed(() => items.value.flatMap(item => item.status === 'failed' && item.file ? [item.file] : []))
  const pending = computed(() => items.value.some(item => item.status === 'queued' || item.status === 'uploading'))
  const blocked = computed(() => items.value.some(item => item.status !== 'done'))
  const state: State<T> = { items, scope, upload: uploadFile, active: null, version: 0, running: null,
    failed: cause => { error.value = uploadFailureMessage(cause) },
    publish: () => { items.value = [...items.value]; emit('change', [...attachments.value]); emit('pending', blocked.value) } }
  function dispose(): void { state.version++; state.active?.abort(); state.active = null; state.running = null }
  function clear(): void { dispose(); items.value = []; error.value = null; state.publish() }
  function restore(prepared: T[]): void {
    const saved = [...prepared]; dispose(); error.value = null
    items.value = saved.map(attachment => ({ key: ++sequence, name: attachment.originalName, sizeBytes: attachment.sizeBytes, attachment, status: 'done', progress: 100 }))
    state.publish()
  }
  async function upload(files: File[]): Promise<void> {
    if (!files.length || disabled()) return
    if (items.value.length + files.length > MAX_MESSAGE_ATTACHMENTS) { error.value = 'К сообщению можно прикрепить не более 10 файлов.'; return }
    error.value = null
    items.value = [...items.value, ...files.map(file => ({ key: ++sequence, name: file.name, sizeBytes: file.size, file, status: 'queued' as const, progress: 0 }))]
    state.publish(); await drain(state)
  }
  async function retry(key?: number): Promise<void> {
    if (disabled()) return
    error.value = null
    for (const item of items.value) if (item.status === 'failed' && (key === undefined || item.key === key)) {
      item.status = 'queued'; item.progress = 0; item.error = undefined
    }
    state.publish(); await drain(state)
  }
  function cancel(key: number): void {
    if (disabled()) return
    const target = items.value.find(item => item.key === key)
    items.value = items.value.filter(item => item.key !== key)
    if (target?.status === 'uploading') state.active?.abort()
    if (!failed.value.length) error.value = null
    state.publish()
  }
  function addFiles(event: Event): void {
    const input = event.currentTarget as HTMLInputElement, files = Array.from(input.files ?? [])
    input.value = ''; void upload(files)
  }
  restore(initial)
  return { items, attachments, failed, pending, blocked, error, upload, retry, cancel, clear, restore, dispose, addFiles }
}
