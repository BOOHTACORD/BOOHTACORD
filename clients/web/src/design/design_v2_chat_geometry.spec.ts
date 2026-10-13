import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const tokens = readFileSync(new URL('./tokens.css', import.meta.url), 'utf8')
const shell = readFileSync(new URL('./shell.css', import.meta.url), 'utf8')
const responsive = readFileSync(new URL('./responsive_shell.css', import.meta.url), 'utf8')
const conversation = readFileSync(new URL('./conversation.css', import.meta.url), 'utf8')
const v2Chat = readFileSync(new URL('./design_v2_chat.css', import.meta.url), 'utf8')
const chatMedia = readFileSync(new URL('./design_v2_chat_media.css', import.meta.url), 'utf8')
const presentation = readFileSync(new URL('./design_v2_chat_presentation.css', import.meta.url), 'utf8')
const overlays = readFileSync(new URL('./design_v2_contextual_overlays.css', import.meta.url), 'utf8')

function pixelToken(name: string): number {
  return Number(tokens.match(new RegExp(`--gc-${name}:\\s*(\\d+)px;`))?.[1])
}

describe('Design V2 chat reference geometry', () => {
  it('matches the R01 1440 px shell columns and header', () => {
    expect(pixelToken('layout-nav-wide')).toBe(280)
    expect(pixelToken('layout-aside-wide')).toBe(248)
    expect(pixelToken('layout-header')).toBe(64)
    expect(1440 - pixelToken('layout-nav-wide') - pixelToken('layout-aside-wide')).toBe(912)
    expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr) var(--gc-layout-aside-wide)')
  })

  it('uses a drawer for members at R03 and a single-column mobile shell at R02', () => {
    expect(responsive).toContain('@media (min-width: 1024px) and (max-width: 1279px)')
    expect(responsive).toContain('@media (max-width: 1023px)')
    expect(responsive).toContain('.members.is-open')
  })

  it('keeps the history, composer, and attachments inside the measured chat body', () => {
    expect(conversation).toContain('.message-list')
    expect(conversation).toContain('.composer-wrap')
    expect(conversation).toContain('.attachment-card__preview')
    expect(chatMedia).toContain('.attachment-card--image')
    expect(chatMedia).toContain('width: min(100%, 440px)')
    expect(chatMedia).toContain('height: 200px')
    expect(pixelToken('layout-header')).toBe(64)
    expect(v2Chat).toContain('.text-conversation .composer-wrap { padding: 8px 24px 16px; }')
    expect(v2Chat).toContain('.attachment-preview { max-width: min(100%, 440px); max-height: 200px; }')
    expect(v2Chat).toContain('.attachment-preview { max-width: 100%; max-height: 144px; }')
    expect(v2Chat).toContain('.conversation-header { height: 56px; min-height: 56px; flex-basis: 56px; }')
    expect(v2Chat).toContain('.text-conversation .composer-wrap { padding: 8px; }')
    expect(v2Chat).toContain('.composer-helper { position: absolute;')
  })

  it('uses the handoff section label in channel navigation', () => {
    expect(presentation).toContain('.channel-navigation-actions { padding-top: 1px; padding-left: 8px; }')
    expect(presentation).toContain('.channel-navigation-actions > span { font-weight: 600; letter-spacing: .6px; text-transform: uppercase; }')
    expect(presentation).toContain('.channel-navigation .channel-member-count { display: none; }')
  })

  it('matches the reference author weight and reserves the history scrollbar', () => {
    expect(presentation).toContain('.text-conversation .message-author { font-weight: 600; }')
    expect(presentation).toContain('.text-conversation .messages { scrollbar-gutter: stable; }')
    expect(presentation).toMatch(/@media \(max-width: 720px\)\s*\{[\s\S]*?\.text-conversation \.messages \{ scrollbar-gutter: auto; \}/)
  })

  it('keeps the R02 mobile composer controls on the reference grid', () => {
    expect(overlays).toContain('.text-conversation .message-composer, .direct-message-conversation .message-composer { gap: 0; }')
    expect(overlays).toContain('.message-composer .attachment-trigger { margin: 0 4px 0 0; }')
    expect(overlays).toContain('.message-composer .composer-send { margin: 0 0 0 4px; }')
    expect(overlays).toContain('.message-composer textarea { font-size: 1rem; line-height: 1.5rem; padding: 10px 0; }')
  })

  it('matches the R01 and R03 desktop composer control sizes', () => {
    expect(overlays).toContain('@media (min-width: 1024px) {')
    expect(overlays).toContain('.text-conversation .message-composer textarea { min-height: calc(var(--gc-line-body) + 14px); height: calc(var(--gc-line-body) + 14px); padding: 7px 0; font-size: 0.9375rem; resize: none; }')
    expect(overlays).toContain('.text-conversation .message-composer .attachment-trigger,')
    expect(overlays).toContain('.text-conversation .message-composer .composer-send { width: 32px; height: 34px; min-height: 34px; flex: 0 0 32px; }')
  })
})
