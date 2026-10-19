import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const source = (path: string) => readFileSync(new URL(path, import.meta.url), 'utf8')

describe('Design V2 viewer toolbar icons', () => {
  it('uses the handoff speaker, chart, expand and menu shapes without a pin icon', () => {
    const audioControl = source('./ScreenViewerAudioControl.vue')
    expect(audioControl).toContain('M15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14')
    expect(audioControl).toContain('<path v-else d="m3 3 18 18"/>')
    const viewer = source('./ScreenViewer.vue')
    expect(viewer).not.toContain('m16 3 5 5-4 2-3 5-2 1-4-4 1-2 5-3 2-4ZM8 16l-5 5')
    expect(viewer).toContain('M8 3H3v5M16 3h5v5M3 16v5h5M21 16v5h-5')
    expect(viewer).toContain('<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>')
    expect(source('./ScreenReceiverDiagnosticsPanel.vue')).toContain('M4 20V4M4 20h17M8 16v-5M13 16V7M18 16v-9')
  })
})
