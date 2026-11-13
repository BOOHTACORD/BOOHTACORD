import { computed, ref, watch } from 'vue'
import type { AudioDevice, AudioDeviceKind } from './audio_devices'

interface DeviceProps {
  inputDeviceId?: string
  connected: boolean
  devices: { inputs: AudioDevice[]; outputs: AudioDevice[] }
}
export function useAudioDeviceSelection(props: DeviceProps, emit: (kind: AudioDeviceKind, id: string) => void) {
  const selectedInput = computed(() => props.inputDeviceId ?? 'default')
  const selectedOutput = ref('default'), deviceWarning = ref('')
  const selectedInputLabel = computed(() => {
    const selected = props.devices.inputs.find(({ id }) => id === selectedInput.value)
    return selected?.label.trim() || (selectedInput.value === 'default' ? 'Системный микрофон' : 'Выбранный микрофон недоступен')
  })
  const selectedOutputLabel = computed(() => {
    const selected = props.devices.outputs.find(({ id }) => id === selectedOutput.value)
    return selected?.label.trim() || 'Системный динамик'
  })
  watch(() => props.devices, ({ outputs }) => {
    if (outputs.length && !outputs.some(({ id }) => id === selectedOutput.value)) {
      if (selectedOutput.value !== 'default') deviceWarning.value = 'Выбранный динамик отключён. Выберите доступное устройство и проверьте звук.'
      selectedOutput.value = outputs[0].id
    }
  }, { immediate: true })
  function choose(kind: AudioDeviceKind, event: Event): void {
    const id = (event.target as HTMLSelectElement).value
    if (kind === 'audiooutput') selectedOutput.value = id
    deviceWarning.value = ''
    if (kind === 'audioinput' || props.connected) emit(kind, id)
  }
  return { selectedInput, selectedOutput, selectedInputLabel, selectedOutputLabel, deviceWarning, choose }
}
