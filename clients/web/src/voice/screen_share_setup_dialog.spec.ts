import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

import ScreenShareSetupDialog from './ScreenShareSetupDialog.vue'
import ScreenDiagnosticsPanel from './ScreenDiagnosticsPanel.vue'
import { normalizeScreenQualitySelection, selectScreenQualityMode, selectScreenQualityResolution } from './screen_share_quality_selection'

describe('screen-share setup dialog', () => {
  it('offers motion/text scenarios and ceiling choices before browser capture', async () => {
    const html = await renderToString(createSSRApp(ScreenShareSetupDialog, {
      initialProfile: 'P1080_30',
    }))

    expect(html).toContain('Демонстрация экрана')
    expect(html).toContain('Плавность')
    expect(html).toContain('Игры и видео · 60 FPS')
    expect(html).toContain('Чёткость текста')
    expect(html).toContain('Документы и код · 15–30 FPS')
    expect(html).toContain('Максимальное разрешение')
    expect(html).toContain('Частота кадров для текста')
    expect(html).toContain('Рекомендуемый профиль')
    expect(html).toContain('<strong>1080p · 60 FPS</strong>')
    expect(html).toContain('Текущий выбор: 1080p · 30 FPS')
    expect(html).toContain('<section class="screen-share-quality__settings" aria-labelledby="screen-share-quality-settings-title">')
    expect(html).toContain('<h4 id="screen-share-quality-settings-title">Качество изображения</h4>')
    expect(html).toContain('720p')
    expect(html).toContain('1080p')
    expect(html).toContain('1440p')
    expect(html).toContain('15 FPS')
    expect(html).toContain('30 FPS')
    expect(html).not.toContain('<span>60 FPS</span>')
    expect([...html.matchAll(/<span>(\d{3,4}p)<\/span>/g)].map((match) => match[1]))
      .toEqual(['720p', '1080p', '1440p'])
    expect([...html.matchAll(/<span>(15|30|60) FPS<\/span>/g)].map((match) => match[1]))
      .toEqual(['15', '30'])
    expect(html).toContain('браузер покажет системный запрос')
    expect(html).toContain('Суммарный лимит двух слоёв')
    expect(html).toContain('не гарантированный сетевой расход')
    expect(html).toContain('Начать трансляцию')
  })

  it('keeps motion at 60 FPS while leaving the 1440p option available', async () => {
    const html = await renderToString(createSSRApp(ScreenShareSetupDialog, { initialProfile: 'P1080_60' }))
    expect(html).toContain('<span class="screen-share-quality__frame-rate-label">Частота кадров для плавности</span>')
    expect(html).toContain('screen-share-quality__single-value')
    expect(html).toContain('Игры и видео · 60 FPS')
    expect(html).toContain('Документы и код · 15–30 FPS')
    expect(html).toMatch(/<input[^>]*name="screen-share-resolution" value="1440"[^>]*>/)
    expect(html).not.toMatch(/<input[^>]*disabled[^>]*value="1440"[^>]*>/)
    expect(html).toContain('1440p автоматически включает сценарий')
  })

  it('moves to the compatible text profile when 1440p is selected from motion', () => {
    const motion = { mode: 'motion' as const, resolution: 1080 as const, frameRate: 60 as const }
    expect(selectScreenQualityResolution(motion, 1440)).toEqual({ mode: 'text', resolution: 1440, frameRate: 30 })
    expect(selectScreenQualityMode({ ...motion, resolution: 1440 }, 'motion')).toEqual({ mode: 'motion', resolution: 1080, frameRate: 60 })
    expect(selectScreenQualityMode(motion, 'text')).toEqual({ mode: 'text', resolution: 1080, frameRate: 30 })
    expect(normalizeScreenQualitySelection({ mode: 'motion', resolution: 1440, frameRate: 60 }))
      .toEqual({ mode: 'text', resolution: 1440, frameRate: 30 })
  })

  it('opens the dialog from both the room action and persistent voice dock', () => {
    const workspace = readFileSync(new URL('../workspace/WorkspaceApp.vue', import.meta.url), 'utf8')
    const pane = readFileSync(new URL('../conversation/ConversationPane.vue', import.meta.url), 'utf8')

    expect(workspace).toContain('<ScreenShareSetupDialog')
    expect(workspace).toContain('@start-screen="openScreenShareSetup"')
    expect(workspace).toContain('@start="confirmScreenShare"')
    expect(pane).toContain('@start-screen="emit(\'startScreen\', $event)"')
    expect(pane).toContain('@change-quality="emit(\'startScreen\', screenProfile ?? selectedScreenProfile)"')
    expect(pane).not.toContain('Целевой профиль<select')
  })

  it('normalizes a saved 1440p60 profile to a startable 1440p30 text profile', async () => {
    const html = await renderToString(createSSRApp(ScreenShareSetupDialog, {
      initialProfile: 'P1440_60',
    }))

    expect(html).toMatch(/<input[^>]*checked[^>]*name="screen-share-resolution" value="1440"[^>]*>/)
    expect(html).toMatch(/<input[^>]*checked[^>]*name="screen-share-mode" value="text"[^>]*>/)
    expect(html).toMatch(/<input[^>]*checked[^>]*name="screen-share-frame-rate" value="30"[^>]*>/)
    expect(html).toContain('Текущий выбор: 1440p · 30 FPS')
    expect(html).not.toMatch(/<button[^>]*class="screen-share-setup__start"[^>]*disabled>/)
  })

  it('shows the current stream quality editor only for an updating sender', async () => {
    const html = await renderToString(createSSRApp(ScreenShareSetupDialog, { initialProfile: 'P1440_60', updating: true }))
    expect(html).toMatch(/<section class="screen-share-quality" aria-labelledby="screen-share-quality-title">/)
    expect(html).toMatch(/<h3[^>]*id="screen-share-quality-title"/)
    expect(html).toContain('Качество трансляции')
    expect(html).toContain('Изменения применятся к текущему показу.')
    expect(html).toContain('При ухудшении сети качество может временно снижаться.')
    expect(html).toContain('<circle cx="12" cy="12" r="9"></circle>')
    expect(html).toContain('<section class="screen-share-quality__settings" aria-labelledby="screen-share-quality-settings-title">')
    expect(html).toContain('Применить')
    expect(html).not.toContain('браузер покажет системный запрос')
  })

  it('labels pre-picker support separately from tracks actually received after selection', async () => {
    const setup = await renderToString(createSSRApp(ScreenShareSetupDialog, { initialProfile: 'P1080_30' }))
    expect(setup).toContain('Поддержка до выбора источника')
    expect(setup).toContain('<summary>Возможности и ограничения источника</summary>')
    expect(setup).toContain('Звук определяется после выбора источника')
    expect(setup).toContain('выбранный источник может не передать аудио')
    expect(setup).not.toContain('игровой звук поддерживается')

    const diagnostics = await renderToString(createSSRApp(ScreenDiagnosticsPanel, {
      profile: 'P1080_30',
      diagnostics: { audioTrack: 'ABSENT', connectionQuality: 'GOOD', measured: null, source: 'ACTIVE' },
    }))
    expect(diagnostics).toContain('Фактически полученные дорожки')
    expect(diagnostics).toContain('Видео: есть')
    expect(diagnostics).toContain('Аудио: нет')
    expect(diagnostics).toContain('Голос остаётся доступен без аудиодорожки экрана')
  })

  it('keeps the dialog styling on shared tokens and adapts quality rows on mobile', () => {
    const styles = readFileSync(new URL('../design/screen_share_setup.css', import.meta.url), 'utf8')
    const imports = readFileSync(new URL('../style.css', import.meta.url), 'utf8')

    expect(imports).toContain("@import './design/screen_share_setup.css';")
    expect(styles).toContain('width: min(560px, calc(100vw - 40px))')
    expect(styles).toContain('var(--gc-sidebar)')
    expect(styles).toContain('@media (max-width: 600px)')
    expect(styles).toContain('grid-template-columns: minmax(0, 1fr)')
    expect(styles).toContain('.screen-share-quality__scenario-title {')
    expect(styles).toContain('white-space: normal;')
    expect(styles).toContain('.screen-share-quality__single-value {')
    expect(styles).toContain('.screen-share-quality__segments { display: grid;')
    expect(styles).toContain('box-shadow: inset 0 0 0 1px var(--gc-accent-text);')
    const updating = readFileSync(new URL('../design/design_v2_screen_quality.css', import.meta.url), 'utf8')
    expect(updating).toContain('.screen-share-setup-dialog--updating::backdrop { background: var(--gc-overlay); backdrop-filter: none; }')
    expect(updating).toContain('background: var(--gc-surface)')
    expect(updating).toContain('background: var(--gc-accent)')
    expect(updating).toContain('background: var(--gc-sidebar)')
    expect(updating).toContain('font-weight: 600; letter-spacing: -.2px')
    expect(updating).toContain('font-weight: 500;')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__footer button { min-height: 44px; flex: 1; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__footer button { min-height: 36px; padding: 0 14px; font-size: 0.875rem; font-weight: 500; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__close svg { width: 20px; height: 20px; stroke-width: 1.8; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__header { position: relative;')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__close { position: absolute; top: 24px; right: 24px; width: 36px; height: 36px; }')
    expect(updating).toContain('.screen-share-setup-dialog--updating .screen-share-setup__close { top: 26px; right: 20px; width: 44px; height: 44px; }')
  })
})
