import { expect, it, vi } from 'vitest'
import { effectScope, reactive, nextTick } from 'vue'
import { useAudioDeviceSelection } from './audio_device_selection'

it('keeps device choices, warning and disconnected output selection behavior', async () => {
  const emit = vi.fn()
  const props = reactive({ inputDeviceId: 'mic', connected: false, devices: {
    inputs: [{ id: 'mic', label: 'Microphone' }], outputs: [{ id: 'speaker', label: 'Speakers' }],
  } })
  const scope = effectScope()
  const selected = scope.run(() => useAudioDeviceSelection(props as never, emit))!
  expect(selected.selectedInputLabel.value).toBe('Microphone')
  expect(selected.selectedOutput.value).toBe('speaker')
  selected.choose('audiooutput', { target: { value: 'speaker' } } as never)
  expect(emit).not.toHaveBeenCalled()
  selected.choose('audioinput', { target: { value: 'mic' } } as never)
  expect(emit).toHaveBeenCalledWith('audioinput', 'mic')
  props.devices = { ...props.devices, outputs: [{ id: 'other', label: 'Other' }] }; await nextTick()
  expect(selected.selectedOutput.value).toBe('other')
  expect(selected.deviceWarning.value).toContain('отключён')
  scope.stop()
})
