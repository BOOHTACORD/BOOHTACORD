import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const component = readFileSync(new URL('./ProfileSettings.vue', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../design/design_v2_identity.css', import.meta.url), 'utf8')
const presentation = readFileSync(new URL('../design/design_v2_profile_presentation.css', import.meta.url), 'utf8')
const tokens = readFileSync(new URL('../design/tokens.css', import.meta.url), 'utf8')
const workspace = readFileSync(new URL('../workspace/WorkspaceMain.vue', import.meta.url), 'utf8')

describe('Design V2 account settings', () => {
  it('keeps profile, security, notifications, and about settings in accessible tabs', () => {
    expect(component).toContain('role="tablist"')
    expect(component.match(/role="tab"/g)).toHaveLength(4)
    expect(component).toContain("activeTab === 'notifications'")
    expect(component).toContain("activeTab === 'about'")
  })

  it('retains avatar, name, password, notification, update, and logout workflows', () => {
    for (const value of ['selectAvatar', 'removeAvatar', 'saveName', 'changePassword', 'NotificationSettings', 'UpdateStatus', "emit('logout')"]) expect(component).toContain(value)
  })

  it('uses the canonical desktop settings card and savebar sizes', () => {
    expect(styles).toContain('min-height: 459px;')
    expect(styles).toContain('height: 57px;')
    expect(styles).toContain('margin: 24px 0 26px;')
  })

  it('uses shared page-heading typography at desktop and compact widths', () => {
    expect(tokens).toContain('--gc-text-page-compact: 1.375rem;')
    expect(tokens).toContain('--gc-line-page-compact: 1.75rem;')
    expect(presentation).toContain('font-size: var(--gc-text-page-compact);')
    expect(presentation).toContain('line-height: var(--gc-line-page-compact);')
  })

  it('places profile identity and save controls in the R12 settings shell', () => {
    expect(workspace).toContain("emit('closePanel', 'profile')")
    expect(component).toContain("slice(0, 2).toLocaleUpperCase('ru-RU')")
    expect(presentation).toContain('.workspace-main-panel--profile .profile-savebar { position: static;')
  })

  it('preserves tablet gutters and avoids doubling the mobile savebar gap', () => {
    expect(presentation).toContain('max-width: 944px;')
    expect(presentation).toContain('max-width: 928px; padding: 24px 24px 48px;')
    expect(presentation).toContain('@media (max-width: 1023px)')
    expect(presentation).toContain('height: 45px; gap: 8px; margin: 24px 0;')
    expect(presentation).toContain('gap: 8px; margin-top: 4px;')
  })
})
