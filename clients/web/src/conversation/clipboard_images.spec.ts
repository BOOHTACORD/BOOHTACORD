import { describe, expect, it, vi } from 'vitest'

import { pasteClipboardImages } from './clipboard_images'

function pasteEvent({
  files = [],
  text = '',
}: { files?: File[]; text?: string } = {}): Pick<ClipboardEvent, 'clipboardData' | 'preventDefault'> {
  const items = files.map((file) => ({
    kind: 'file',
    type: file.type,
    getAsFile: () => file,
  })) as unknown as DataTransferItemList
  const clipboardData = {
    items,
    files: files as unknown as FileList,
    getData: (type: string) => type === 'text/plain' ? text : '',
  } as DataTransfer
  return { clipboardData, preventDefault: vi.fn() }
}

describe('clipboard image paste', () => {
  it('uploads pasted images without altering ordinary text paste', () => {
    const event = pasteEvent({ files: [new File(['image'], 'capture.png', { type: 'image/png' })] })
    const input = { selectionStart: 2, selectionEnd: 4, setRangeText: vi.fn(), dispatchEvent: vi.fn() }
    const addFiles = vi.fn()

    expect(pasteClipboardImages(event, input, addFiles)).toBe(true)
    expect(event.preventDefault).toHaveBeenCalledOnce()
    expect(addFiles.mock.calls[0]?.[0]).toMatchObject([{ name: 'capture.png', type: 'image/png' }])

    const textEvent = pasteEvent({ text: 'обычный текст' })
    expect(pasteClipboardImages(textEvent, input, addFiles)).toBe(false)
    expect(textEvent.preventDefault).not.toHaveBeenCalled()
    expect(addFiles).toHaveBeenCalledOnce()
  })

  it('preserves accompanying text at the selection and gives anonymous blobs a filename', () => {
    const event = pasteEvent({
      files: [new File(['image'], '', { type: 'image/jpeg' })],
      text: 'подпись',
    })
    const input = { selectionStart: 1, selectionEnd: 3, setRangeText: vi.fn(), dispatchEvent: vi.fn() }
    const addFiles = vi.fn()

    expect(pasteClipboardImages(event, input, addFiles)).toBe(true)
    expect(input.setRangeText).toHaveBeenCalledWith('подпись', 1, 3, 'end')
    expect(input.dispatchEvent).toHaveBeenCalledOnce()
    expect(addFiles.mock.calls[0]?.[0]).toMatchObject([{ name: 'clipboard-image-1.jpg' }])
  })

  it('ignores non-image files and plain clipboard text', () => {
    const event = pasteEvent({ files: [new File(['text'], 'note.txt', { type: 'text/plain' })], text: 'note' })
    const input = { selectionStart: 0, selectionEnd: 0, setRangeText: vi.fn(), dispatchEvent: vi.fn() }
    const addFiles = vi.fn()

    expect(pasteClipboardImages(event, input, addFiles)).toBe(false)
    expect(event.preventDefault).not.toHaveBeenCalled()
    expect(input.setRangeText).not.toHaveBeenCalled()
    expect(addFiles).not.toHaveBeenCalled()
  })

  it('uses image FileList fallback when file items cannot be materialized', () => {
    const event = pasteEvent({ files: [new File(['image'], 'blob', { type: 'image/png' })] })
    Object.assign(event.clipboardData!, { items: [{ kind: 'file', type: 'image/png', getAsFile: () => null }] })
    const add = vi.fn()
    expect(pasteClipboardImages(event, { selectionStart: 0, selectionEnd: 0, setRangeText: vi.fn(), dispatchEvent: vi.fn() }, add)).toBe(true)
    expect(add.mock.calls[0]?.[0]).toMatchObject([{ name: 'clipboard-image-1.png', size: 5 }])
  })

  it('leaves a missing clipboard untouched', () => {
    const event = { clipboardData: null, preventDefault: vi.fn() }, add = vi.fn()
    expect(pasteClipboardImages(event, { selectionStart: 0, selectionEnd: 0, setRangeText: vi.fn(), dispatchEvent: vi.fn() }, add)).toBe(false)
    expect(event.preventDefault).not.toHaveBeenCalled(); expect(add).not.toHaveBeenCalled()
  })
})
