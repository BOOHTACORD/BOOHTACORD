import { nextTick, type Ref } from 'vue'
import { insertEmojiAtRange } from '../emoji_insert'
import { pasteClipboardImages } from '../clipboard_images'
import { createComposerDrop } from '../upload_queue/drop'
import { useComposerTextareaAutosize } from './auto_size'

export function useComposerInput(draft: Ref<string>, textarea: Ref<HTMLTextAreaElement | null>, picker: Ref<{ addPastedFiles(files: File[]): void } | null>, enabled: () => boolean) {
  useComposerTextareaAutosize(draft, textarea)
  const add = (files: File[]) => picker.value?.addPastedFiles(files)
  async function addEmoji(emoji: string): Promise<void> {
    const input = textarea.value
    const result = insertEmojiAtRange(draft.value, input?.selectionStart ?? draft.value.length, input?.selectionEnd ?? draft.value.length, emoji)
    draft.value = result.text
    await nextTick()
    input?.focus(); input?.setSelectionRange(result.caret, result.caret)
  }
  function insertMobileMention(): void { draft.value += draft.value && !/\s$/.test(draft.value) ? ' @' : '@'; void nextTick(() => textarea.value?.focus()) }
  function onComposerPaste(event: ClipboardEvent): void {
    if (textarea.value && enabled()) pasteClipboardImages(event, textarea.value, add)
  }
  return { addEmoji, insertMobileMention, onComposerPaste, ...createComposerDrop(add, enabled) }
}
