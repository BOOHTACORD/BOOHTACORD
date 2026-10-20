import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const dock = readFileSync(new URL('./VoiceDock.vue', import.meta.url), 'utf8')
const controls = readFileSync(new URL('./VoiceRoomControls.vue', import.meta.url), 'utf8')
const voiceStyles = readFileSync(new URL('../design/voice.css', import.meta.url), 'utf8')
const dockStyles = readFileSync(new URL('../design/design_v2_voice_dock.css', import.meta.url), 'utf8')
const desktopDockStyles = readFileSync(new URL('../design/design_v2_chat_presentation.css', import.meta.url), 'utf8')
const mobileDockStyles = readFileSync(new URL('../design/design_v2_mobile_navigation.css', import.meta.url), 'utf8')

describe('Design V2 voice dock icons', () => {
  it('uses the handoff microphone outline while keeping the existing action', () => {
    expect(controls).toContain('<rect x="9" y="2" width="6" height="12" rx="3"/>')
    expect(controls).toContain('M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8')
    expect(controls).toContain("@click=\"props.toggleMicrophone\"")
  })

  it('uses the handoff monitor icon while retaining screen share events', () => {
    expect(controls).toContain('<rect x="2" y="3" width="20" height="14" rx="2"/>')
    expect(controls).toContain('<path d="M8 21h8M12 17v4"/>')
    expect(controls).toContain('<path v-else d="m8 11 4-4 4 4M12 7v6"/>')
    expect(controls).toContain('@click="activateScreenShare"')
    expect(controls).toContain("emit('stopScreen')")
    expect(controls).toContain("emit('startScreen', props.selectedScreenProfile)")
  })

  it('uses a bolder filled end-call glyph and balanced desktop control sizing', () => {
    expect(controls).toContain('class="voice-icon voice-icon--filled"')
    expect(controls).toContain('class="voice-icon voice-icon--filled" viewBox="0 0 24 24"')
    expect(dockStyles).toContain('.voice-dock .voice-icon { stroke-width: 2; }')
    expect(dockStyles).toContain('.voice-dock .voice-icon--filled { fill: currentColor; stroke: none; }')
    expect(desktopDockStyles).toContain('.sidebar .mobile-voice-dock .voice-icon-button { width: auto; height: 40px; flex: 1 1 0; min-width: 0; }')
  })

  it('fills the desktop and open-drawer dock width with evenly sized action targets', () => {
    expect(desktopDockStyles).toContain('.sidebar .mobile-voice-dock .voice-actions { width: 100%;')
    expect(desktopDockStyles).toContain('.sidebar .mobile-voice-dock .voice-icon-button { width: auto; height: 40px; flex: 1 1 0; min-width: 0; }')
    expect(mobileDockStyles).toContain('.sidebar.is-open .mobile-voice-dock .voice-actions { display: flex; width: 100%;')
    expect(mobileDockStyles).toContain('min-height: 44px; flex: 1 1 0; min-width: 0;')
    expect(mobileDockStyles).toContain('width: 44px; height: 44px; min-height: 44px;')
  })

  it('uses the same headphones outline for the header and deafen control', () => {
    expect(dock).toContain('M3 14v-3a9 9 0 0 1 18 0v3')
    expect(controls).toContain('M3 14v-3a9 9 0 0 1 18 0v3')
    expect(controls).toContain("@click=\"props.toggleDeafen\"")
  })

  it('marks muted and deafened controls with a high-contrast persistent red state', () => {
    expect(controls).toContain("'voice-icon-button--danger-active': microphoneMuted")
    expect(controls).toContain("'voice-icon-button--danger-active': deafened")
    expect(voiceStyles).toMatch(/\.voice-icon-button--danger-active\s*\{[^}]*border:\s*1px solid var\(--gc-danger\)[^}]*color:\s*var\(--gc-on-danger\)[^}]*background:\s*var\(--gc-danger-solid\)/)
  })
})
