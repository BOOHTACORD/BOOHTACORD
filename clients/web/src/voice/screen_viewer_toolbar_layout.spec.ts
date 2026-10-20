import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(path: string): string { return readFileSync(new URL(path, import.meta.url), 'utf8') }

describe('selected-stream toolbar layout', () => {
  it('keeps audio, statistics and fullscreen controls beside the real player without a pin action', () => {
    const viewer = source('./ScreenViewer.vue')
    const rail = source('./ScreenViewerRail.vue')
    const css = source('../design/design_v2_screen_viewer.css')
    expect(viewer).toContain('class="stream-quality-row"')
    expect(viewer).toContain('ScreenViewerAudioControl')
    expect(viewer).toContain('ScreenReceiverDiagnosticsPanel')
    expect(viewer).toContain('class="screen-fullscreen-button stream-tool-button"')
    expect(viewer).not.toContain('Закрепить просмотр')
    expect(viewer).toContain('<ScreenViewerRail')
    expect(rail).not.toContain("emit('returnVoice')")
    expect(css).toContain('grid-template-rows: minmax(0, 1fr) auto 48px auto 92px')
    expect(css).toContain('grid-template-rows: minmax(0, 1fr) auto 56px auto 92px')
    expect(css).toContain('.voice-room .screen-player { width: 100%; height: 100%; max-height: 100%; object-fit: contain; background: #050608; }')
    expect(css).toContain('min-height: 44px;')
  })

  it('matches Flutter with a real participant strip below the stream selector', () => {
    const viewer = source('./ScreenViewer.vue')
    const rail = source('./ScreenViewerRail.vue')
    const pane = source('../conversation/ConversationPane.vue')
    const participants = source('./ScreenViewerParticipantStrip.vue')
    const css = source('../design/design_v2_screen_viewer.css')

    expect(pane).toContain(':participants="voiceVolumeParticipants"')
    expect(pane).toContain(':self-name="selfDisplayName"')
    expect(viewer).toContain('<ScreenViewerParticipantStrip')
    expect(viewer).toContain(':participants="participants"')
    expect(viewer).toContain(':self-microphone-unavailable="selfMicrophoneUnavailable"')
    expect(viewer.indexOf('<ScreenViewerRail')).toBeLessThan(viewer.indexOf('<ScreenViewerParticipantStrip'))
    expect(rail).not.toContain('Участники · {{ participantCount }}')
    expect(participants).toContain('Участники')
    expect(participants).toContain('в комнате')
    expect(participants).toContain('<VoiceParticipantStatus')
    expect(participants).toContain('sharesScreen')
    expect(css).toContain('.voice-room .voice-viewer-participant-strip')
    expect(css).toContain('width: 176px;')
  })

  it('offers quality changes only to the active sender and exposes receiver statistics', () => {
    const viewer = source('./ScreenViewer.vue')
    const panel = source('./ScreenReceiverDiagnosticsPanel.vue')
    const css = source('../design/design_v2_stream_diagnostics.css')
    expect(viewer).toContain('v-if="ownScreenSharing"')
    expect(viewer).toContain('function changeQuality()')
    expect(viewer).toContain("emit('changeQuality')")
    expect(panel).toContain('aria-label="Статистика"')
    expect(panel).toContain('screenSampleAge(props.sampledAt)')
    expect(panel).toContain('Потери пакетов за 10 с')
    expect(panel).toContain('alignLeft: window.innerWidth <= 1100')
    expect(css).toContain('.stream-diagnostics-backdrop')
    expect(css).toContain('height: min(514px, 80dvh)')
  })

  it('matches the HTML thumbnail insets and captions while retaining horizontal scrolling', () => {
    const css = source('../design/design_v2_screen_viewer.css')
    expect(css).toContain('.voice-room .screen-cards .stream-option { width: 128px; min-width: 128px; height: 80px; min-height: 80px; }')
    expect(css).toContain('padding: 0 6px; background: var(--gc-sidebar);')
    expect(css).toContain('.stream-card-preview { height: 50px; min-height: 50px; }')
    expect(css).toContain('position: absolute; top: 14px; left: 8px;')
    expect(css).toContain('height: 28px; min-height: 28px;')
    expect(css).toContain('gap: 6px; padding: 4px 8px;')
    expect(css).toContain('.screen-cards.stream-rail.has-overflow::after { display: none; }')
    expect(css).toContain('.voice-room .workspace-header-toggle--nav, .voice-room .workspace-header-toggle--members { width: 44px; height: 44px; }')
  })

  it('keeps mobile viewer actions in equal touch targets with reference spacing', () => {
    const css = source('../design/design_v2_screen_viewer.css')
    expect(css).toContain('.stream-toolbar-actions { gap: 2px; }')
    expect(css).toContain('.stream-toolbar-actions .stream-diagnostics { flex: 0 0 44px; }')
    expect(css).toContain('height: 56px; min-height: 56px; gap: 2px; padding: 4px;')
    expect(css).toContain('width: 20px; height: 20px;')
    expect(css).toContain('stroke-width: 1.8;')
    expect(css).not.toContain('margin-right: -6px')
  })

  it('uses the shared live badge and identity palette for the selected participant', () => {
    const css = source('../design/design_v2_screen_viewer.css')
    const viewer = source('./ScreenViewer.vue')
    expect(css).toContain('padding: 2px 6px; color: #FF9AD5; background: #3D1831; font-size: 0.75rem; line-height: 1rem;')
    expect(viewer).toContain('avatarBackground(selectedStream.accountId ?? selectedStream.participantId)')
    expect(viewer).toContain('avatarForeground(selectedStream.accountId ?? selectedStream.participantId)')
  })

  it('styles the real audio slider while preserving its 0–200 percent range', () => {
    const control = source('./ScreenViewerAudioControl.vue')
    const css = source('../design/design_v2_screen_viewer.css')
    expect(control).toContain('min="0" max="200" step="1" :value="volume"')
    expect(control).toContain("'--screen-audio-level': `${volume / 2}%`")
    expect(css).toContain('height: 4px; margin: 0;')
    expect(css).toContain('::-webkit-slider-thumb')
    expect(css).toContain('::-moz-range-thumb')
  })
})
