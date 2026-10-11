import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const dock = readFileSync(new URL('./VoiceDock.vue', import.meta.url), 'utf8')
const voiceStyles = readFileSync(new URL('../design/voice.css', import.meta.url), 'utf8')
const dockStyles = readFileSync(new URL('../design/design_v2_voice_dock.css', import.meta.url), 'utf8')
const desktopDockStyles = readFileSync(new URL('../design/design_v2_chat_presentation.css', import.meta.url), 'utf8')

describe('Design V2 voice dock icons', () => {
  it('uses the handoff microphone outline while keeping the existing action', () => {
    expect(dock).toContain('<rect x="9" y="2" width="6" height="12" rx="3"/>')
    expect(dock).toContain('M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8')
    expect(dock).toContain("@click=\"emit('toggleMicrophone')\"")
  })

  it('uses the handoff monitor icon while retaining screen share events', () => {
    expect(dock).toContain('<rect v-else x="2" y="3" width="20" height="14" rx="2"/>')
    expect(dock).toContain('<path v-if="screenShareState !== \'SHARING\'" d="M8 21h8M12 17v4"/>')
    expect(dock).toContain('<path v-if="screenShareState !== \'SHARING\'" d="m8 11 4-4 4 4M12 7v6"/>')
    expect(dock).toContain("emit('stopScreen') : emit('startScreen')")
  })

  it('uses a bolder filled end-call glyph and balanced desktop control sizing', () => {
    expect(dock).toContain('class="voice-icon voice-icon--filled"')
    expect(dock).toContain('class="voice-icon voice-icon--filled" viewBox="0 0 24 24"')
    expect(dockStyles).toContain('.voice-dock .voice-icon { stroke-width: 2; }')
    expect(dockStyles).toContain('.voice-dock .voice-icon--filled { fill: currentColor; stroke: none; }')
    expect(desktopDockStyles).toContain('.sidebar .mobile-voice-dock .voice-icon-button { width: 40px; height: 40px; flex: 0 0 40px; }')
  })

  it('uses the same headphones outline for the header and deafen control', () => {
    expect(dock.match(/M3 14v-3a9 9 0 0 1 18 0v3/g)).toHaveLength(2)
    expect(dock).toContain("@click=\"emit('toggleDeafen')\"")
  })

  it('marks muted and deafened controls with a high-contrast persistent red state', () => {
    expect(dock).toContain("'voice-icon-button--danger-active': microphoneMuted")
    expect(dock).toContain("'voice-icon-button--danger-active': deafened")
    expect(voiceStyles).toMatch(/\.voice-icon-button--danger-active\s*\{[^}]*border:\s*1px solid var\(--gc-danger\)[^}]*color:\s*var\(--gc-on-danger\)[^}]*background:\s*var\(--gc-danger-solid\)/)
  })
})
