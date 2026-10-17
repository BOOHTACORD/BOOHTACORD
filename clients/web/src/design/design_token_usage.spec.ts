import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const tokens = readFileSync(new URL('./tokens.css', import.meta.url), 'utf8')
const tokenColors = new Set(
  [...tokens.matchAll(/--gc-[\w-]+:\s*(#[0-9a-fA-F]{6});/g)].map((match) => match[1].toLowerCase()),
)
const tokenizedStylesheets = [
  'design_v2_admin_members.css',
  'design_v2_authentication_presentation.css',
  'design_v2_mobile_navigation.css',
  'design_v2_member_popover.css',
  'design_v2_screen_viewer.css',
  'design_v2_voice_room.css',
]

describe('Design V2 component color tokens', () => {
  it('references semantic tokens instead of repeating canonical palette values', () => {
    for (const filename of tokenizedStylesheets) {
      const stylesheet = readFileSync(new URL(`./${filename}`, import.meta.url), 'utf8')
      const repeatedColors = [...stylesheet.matchAll(/#[0-9a-fA-F]{6}\b/g)]
        .map((match) => match[0].toLowerCase())
        .filter((value) => tokenColors.has(value))

      expect(repeatedColors, filename).toEqual([])
    }
  })

  it('uses the shared type scale for repeated administration and authentication headings', () => {
    const admin = readFileSync(new URL('./design_v2_admin_members.css', import.meta.url), 'utf8')
    const authentication = readFileSync(new URL('./design_v2_authentication_presentation.css', import.meta.url), 'utf8')
    const memberPopover = readFileSync(new URL('./design_v2_member_popover.css', import.meta.url), 'utf8')

    expect(admin).toContain('.admin-panel--members .admin-panel-heading h1 { font-size: var(--gc-text-page); line-height: var(--gc-line-page); font-weight: var(--gc-weight-semibold); }')
    expect(admin).toContain('.admin-panel--members .admin-section-heading h2 { font-size: var(--gc-text-section); line-height: var(--gc-line-section); font-weight: var(--gc-weight-semibold); }')
    expect(authentication).toContain('.authentication-card h1 { margin: 32px 0 0; text-align: center; font-size: var(--gc-text-page); line-height: var(--gc-line-page); font-weight: var(--gc-weight-semibold); }')
    expect(memberPopover).toContain('.member-popover .member-popover-identity h2 { font-size: var(--gc-text-title); line-height: var(--gc-line-title); font-weight: var(--gc-weight-semibold); }')
  })
})
