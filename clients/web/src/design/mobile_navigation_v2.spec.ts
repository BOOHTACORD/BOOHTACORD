import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import postcss from 'postcss'
import workspace from '../workspace/WorkspaceApp.vue?raw'
import userFooter from '../workspace/WorkspaceUserFooter.vue?raw'
const mobileNavigation = readFileSync(new URL('./design_v2_mobile_navigation.css', import.meta.url), 'utf8')
const userFooterStyles = readFileSync(new URL('./design_v2_user_footer.css', import.meta.url), 'utf8')
const responsiveShell = readFileSync(new URL('./responsive_shell.css', import.meta.url), 'utf8')
const searchLauncher = readFileSync(new URL('../search/SearchLauncher.vue', import.meta.url), 'utf8')
const navigation = readFileSync(new URL('./navigation.css', import.meta.url), 'utf8')
const dock = readFileSync(new URL('../voice/VoiceDock.vue', import.meta.url), 'utf8')

describe('V2 mobile navigation drawer', () => {
  it('keeps real navigation controls and voice session actions inside the open drawer', () => {
    expect(workspace).toContain('aria-label="Закрыть навигацию"')
    expect(workspace).toContain('@click="toggleNavigation"')
    expect(workspace).toMatch(/<VoiceDock\b[^>]*class="mobile-voice-dock"/)
    expect(mobileNavigation).toContain('.sidebar.is-open .mobile-voice-dock.mobile-visible')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer')
  })

  it('uses the handoff background for the connected mobile voice dock', () => {
    expect(responsiveShell).toMatch(/\.sidebar \.mobile-voice-dock\.mobile-visible \{[^}]*background: #10191a;/)
  })

  it('matches the compact voice roster geometry in the open drawer', () => {
    expect(mobileNavigation).toContain('.sidebar.is-open .channel-button.voice-connected:not(.selected) { color: var(--gc-text-secondary); }')
    expect(mobileNavigation).toContain('.sidebar.is-open .channel-button.voice-connected::before { display: none; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .voice-member-list { margin-top: 5px; padding-left: 36px; gap: 0; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .voice-member-row { min-height: 36px; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .voice-member-avatar { width: 22px; height: 22px; flex-basis: 22px; font-size: 0.5625rem; }')
  })

  it('shows the connected headset only in the open drawer dock', () => {
    expect(dock).toContain('class="voice-dock-headset"')
    expect(mobileNavigation).toContain('.sidebar.is-open .mobile-voice-dock .voice-dock-headset')
  })

  it('uses the reference search outline and drawer alignment', () => {
    expect(searchLauncher).toContain('<circle cx="10.5" cy="10.5" r="6.5"')
    expect(searchLauncher).toContain('<path d="m16 16 5 5"')
    expect(navigation).toContain('.guild-search-button > svg { width: 16px; height: 16px;')
    expect(mobileNavigation).toMatch(/\.sidebar\.is-open > \.guild-header \{[^}]*padding-left: 12px;/)
    expect(mobileNavigation).toContain('.sidebar.is-open .guild-search-button { padding: 0 10px;')
    expect(mobileNavigation).toContain('padding: 12px 14px; background: var(--gc-canvas);')
    expect(mobileNavigation).toContain('background: var(--gc-canvas); font-weight: 400;')
  })

  it('aligns the open drawer account row and keeps settings touchable', () => {
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer {')
    expect(mobileNavigation).toContain('gap: 10px; border-top: 1px solid #292d39; border-right: 0;')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer-profile { gap: 10px; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer .username { gap: 0; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer small { line-height: 1rem; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer-settings { width: 44px; height: 44px; flex-basis: 44px; }')
  })

  it('matches the handoff search and segmented tabs in the open drawer', () => {
    const drawer: Record<string, string> = {}
    postcss.parse(mobileNavigation).walkRules(rule => {
      if (rule.selector === '.sidebar.is-open > .nav-drawer') {
        rule.walkDecls(declaration => { drawer[declaration.prop] = declaration.value })
      }
    })
    expect(drawer).toMatchObject({ 'box-sizing': 'border-box', 'border-right': '0' })
    expect(mobileNavigation).toContain('.sidebar.is-open .guild-search-button { padding: 0 10px; border: 0; color: var(--gc-text-muted);')
    expect(mobileNavigation).toContain('.sidebar.is-open .sidebar-tabs { box-sizing: border-box; width: calc(100% - 24px); height: 40px;')
    expect(mobileNavigation).toContain('.sidebar.is-open .sidebar-tabs button { height: 32px; min-height: 32px;')
    expect(mobileNavigation).toContain('.sidebar.is-open .sidebar-tabs button.is-selected { background: var(--gc-surface-raised); }')
  })

  it('uses a centered settings cog with a larger, touchable target and live handler', () => {
    expect(workspace).toContain('aria-label="Закрыть навигацию" @click="toggleNavigation"><svg')
    expect(workspace).toContain('d="m6 6 12 12M18 6 6 18"')
    expect(userFooter).toContain('<circle cx="12" cy="12" r="3" />')
    expect(userFooterStyles).toContain('width: 40px; height: 40px; flex: 0 0 40px;')
    expect(userFooterStyles).toContain('width: 22px; height: 22px; stroke-width: 1.9;')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer-settings { width: 44px; height: 44px; flex-basis: 44px; }')
    expect(userFooter).toContain('aria-label="Настройки аудио" title="Настройки аудио"')
    expect(userFooter).toContain('@click="emit(\'openSettings\')"')
  })
})
