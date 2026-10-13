import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'

import ScreenReceiverDiagnosticsPanel from './ScreenReceiverDiagnosticsPanel.vue'

function source(path: string): string { return readFileSync(new URL(path, import.meta.url), 'utf8') }

describe('selected screen receiver panel', () => {
  it('shows a recent percentage with a ten-second label', async () => {
    const html = await renderToString(createSSRApp(ScreenReceiverDiagnosticsPanel, {
      actualVideoQuality: '1280 × 720 · 30 FPS', hasAudio: false, isLocal: false,
      metrics: { bitrateKbps: 500, decodedFps: 30, droppedFrames: 0, jitterMs: 2, packetsLost: 2476, packetLossPercent: 0.5 },
      sampledAt: 1000,
    }))
    expect(html).toContain('aria-label="Статистика"')
    expect(source('./ScreenReceiverDiagnosticsPanel.vue')).toContain('Потери пакетов за 10 с')
    expect(source('./ScreenReceiverDiagnosticsPanel.vue')).toContain('percent(metrics?.packetLossPercent)')
    expect(new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 2 }).format(0.5)).toBe('0,5')
    expect(html).not.toContain('>2476<')
  })

  it('shows measured receiver values only when available and keeps unavailable RTT explicit', () => {
    const viewer = source('./ScreenViewer.vue')
    const panel = source('./ScreenReceiverDiagnosticsPanel.vue')
    const styles = source('../design/voice_viewer_reference.css')
    const freshness = source('./screen_profile_metadata/profile.ts')
    const metadata = source('./screen_profile_metadata/presentation.ts')

    expect(viewer).toContain('<ScreenReceiverDiagnosticsPanel')
    expect(panel).toContain('<details ref="diagnostics" class="stream-diagnostics" @toggle="handleToggle">')
    expect(panel).toContain('screenSampleAge(null)')
    expect(freshness).toContain('Нет свежих данных')
    expect(panel).toContain('Декодирование')
    expect(panel).toContain('Показ кадров')
    expect(panel).toContain('Потери пакетов за 10 с')
    expect(panel).toContain('packetLossPercent')
    expect(panel).toContain('Нет данных от приёмника')
    expect(metadata).toContain('Нет данных от отправителя')
    expect(metadata).toContain('Профиль при запуске · имя дорожки')
    expect(panel).toContain('Размер захвата отправителя')
    expect(panel).toContain('Лимиты кодирования отправителя')
    expect(panel).toContain("hasAudio ? 'Есть в LiveKit' : 'Нет в LiveKit'")
    expect(styles).toContain('width: min(288px, calc(100vw - 32px))')
    expect(styles).toContain('font-variant-numeric: tabular-nums')
    expect(styles).toContain('.stream-diagnostics-panel { position: fixed;')
    expect(styles).toContain('overflow-y: auto')
    expect(panel).toContain('@toggle="handleToggle"')
    expect(panel).toContain('popover.style.top = `${result.top}px`')
    expect(panel).toContain('popover.style.left = `${result.left}px`')
    expect(panel).toContain('placeScreenDiagnostics')
    expect(source('../design/design_v2_stream_diagnostics.css')).toContain('height: min(514px, 80dvh)')
  })

  it('returns focus to the trigger after closing the mobile statistics sheet', () => {
    const panel = source('./ScreenReceiverDiagnosticsPanel.vue')
    expect(panel).toContain('aria-modal')
    expect(panel).toContain("event.key === 'Escape'")
    expect(panel).toContain("querySelector('summary')?.focus()")
    expect(panel).toContain("querySelector<HTMLButtonElement>('header button')?.focus()")
  })
})
