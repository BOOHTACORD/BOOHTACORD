import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const component = readFileSync(new URL('./AudioSettings.vue', import.meta.url), 'utf8')
const deviceCheck = readFileSync(new URL('./AudioDeviceCheck.vue', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../design/design_v2_audio.css', import.meta.url), 'utf8')
const presentation = readFileSync(new URL('../design/design_v2_audio_presentation.css', import.meta.url), 'utf8')
const workspace = readFileSync(new URL('../workspace/WorkspaceMain.vue', import.meta.url), 'utf8')

describe('Design V2 audio settings', () => {
  it('keeps device selection, local checks, activation, and processing under their existing stores', () => {
    for (const value of ['choose(\'audioinput\'', 'choose(\'audiooutput\'', 'AudioDeviceCheck', "emit('setActivation'", "emit('setProcessing'"]) expect(component).toContain(value)
  })

  it('matches the desktop and mobile device panel sizes from R10/R11', () => {
    expect(styles).toContain('height: 282px;')
    expect(styles).toContain('height: 402px;')
    expect(styles).toContain('grid-template-columns: repeat(2, minmax(0, 1fr));')
  })

  it('shows a settings toolbar, segmented activation and visible processing controls', () => {
    expect(workspace).toContain('<SettingsWorkspaceHeader panel="audio"')
    expect(component).toContain('class="audio-activation-selector"')
    expect(component).toContain('class="audio-processing-row"')
    expect(presentation).toContain('.audio-settings-panel { display: contents;')
  })

  it('retains the local microphone check lifecycle behind the V2 level meter', () => {
    expect(deviceCheck).toContain('startMicrophoneCheck(')
    expect(deviceCheck).toContain('onBeforeUnmount(stopInput)')
    expect(deviceCheck).toContain('watch(() => props.inputId, stopInput)')
    expect(deviceCheck).toContain('class="audio-level-meter"')
  })

  it('uses the handoff speaker icon for the output check', () => {
    expect(deviceCheck).toContain('M15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14')
  })

  it('matches the handoff medium weight for device labels', () => {
    expect(presentation).toMatch(/\.audio-device-section label \{[^}]*font-weight: 500;/)
  })

  it('keeps full selected hardware labels available when the native select truncates', () => {
    expect(component).toContain('selectedInputLabel')
    expect(component).toContain('selectedOutputLabel')
    expect(component).toContain(':title="selectedInputLabel"')
    expect(component).toContain(':title="selectedOutputLabel"')
    expect(component).toContain('>{{ device.label }}</option>')
  })

  it('uses content-sized cards and a mounted native disclosure for advanced controls', () => {
    expect(presentation).toContain('height: max-content; min-height: 0;')
    expect(component).toContain('<details class="audio-advanced">')
    expect(component).not.toContain('v-if="advanced')
  })

  it('removes native checkbox margins and uses the reference inactive switch color', () => {
    expect(presentation).toMatch(/input\[role=switch\] \{[^}]*margin: 0;/)
    expect(presentation).toMatch(/input\[role=switch\] \{[^}]*background: var\(--gc-border-control\);/)
  })

  it('keeps checkbox row labels at the same body size as button row labels', () => {
    expect(presentation).toMatch(/\.workspace-main-panel--audio \.audio-processing-row \{[^}]*color: var\(--gc-text-primary\);[^}]*font-size: 0.875rem;/)
  })

  it('keeps content gutters on tablet and uses the handoff mobile breakpoint', () => {
    expect(presentation).toContain('max-width: 944px;')
    expect(presentation).toContain('padding: 32px 32px 48px;')
    expect(presentation).toContain('max-width: 928px; padding: 24px 24px 48px;')
    expect(presentation).toContain('@media (max-width: 1023px)')
  })
})
