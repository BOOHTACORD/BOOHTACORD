import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(relativePath: string): string {
  return readFileSync(new URL(relativePath, import.meta.url), 'utf8')
}

describe('screen viewer layout reference', () => {
  it('shows the rail overflow affordance only while content remains', () => {
    const viewer = source('./ScreenViewer.vue') + source('./ScreenViewerRail.vue')
    const styles = source('../design/voice_viewer_reference.css')
    const tokens = source('../design/tokens.css')

    expect(viewer).toContain('observeHorizontalOverflow')
    expect(viewer).toContain('hasOverflow')
    expect(viewer).toContain(':aria-description=')
    expect(styles).toContain('.screen-cards.stream-rail.has-overflow::after')
    expect(styles).toContain('var(--gc-surface) 70%')
    expect(styles).not.toContain('--gc-surface-base')
    expect(tokens).toContain('--gc-layout-row-voice-member: 24px')
  })

  it('keeps one media player while the same view moves between full, mini and pinned modes', () => {
    const viewer = source('./ScreenViewer.vue')
    const pane = source('../conversation/ConversationPane.vue')

    expect(viewer.match(/<video\b/g)).toHaveLength(1)
    expect(viewer.match(/<audio\b/g)).toHaveLength(1)
    expect(viewer).not.toMatch(/<(video|audio)\b[^>]*\bv-if=/)
    expect(pane).toContain(':disabled="!screenExpanded && !(miniVisible && miniPlayerTarget)"')
    expect(pane).toContain(':mini="miniVisible"')
    expect(pane).toContain(':pinned="screenPinned"')
  })

  it('stacks viewer controls at zoomed and narrow widths', () => {
    const styles = source('../design/voice_viewer_reference.css')

    expect(styles).toContain('@media (max-width: 1100px)')
    expect(styles).toContain('.stream-quality-row .volume-control, .stream-audio-status:not(.gc-sr-only)')
    expect(styles).toContain('.stream-quality-row, .stream-quality, .stream-voice-return { flex-wrap: wrap; }')
    expect(styles).toContain('.stream-voice-return button:first-of-type { margin-left: 0; }')
  })
})
