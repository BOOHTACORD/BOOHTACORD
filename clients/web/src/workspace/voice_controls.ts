import { bindMicrophoneAccount } from '../voice/microphone_processing/runtime'
import { voiceSoundPreferences, soundQueue, soundsDeafened, legacySoundReview } from '../voice/sound_playback/runtime'
import { computed, onBeforeUnmount, onMounted, watch } from 'vue'

import type { TopologyChannel } from '../channel/topology_client'
import { useTopologyStore } from '../channel/topology_store'
import { useAudioSettingsStore } from '../voice/audio_settings_store'
import type { AudioDeviceKind } from '../voice/audio_devices'
import { useVoiceActivationStore } from '../voice/activation_store'
import { useVoiceConnectionStore } from '../voice/connection_store'
import type { ScreenProfile } from '../voice/livekit_gateway'
import { useVoiceNavigationStore } from '../voice/navigation_store'
import { createWorkspaceVoiceJoin } from './voice_join/action'
import { stopJourneyRun } from '../telemetry/journey_intervals/runtime'
import { executeVoiceShortcut } from '../voice/shortcuts/execute'
import { VoiceShortcuts } from '../voice/voice_shortcuts'
import type { VoiceShortcutSource } from '../voice/voice_shortcuts'

export function useWorkspaceVoiceControls(accountId = '') {
  const topologyStore = useTopologyStore()
  const audioSettings = useAudioSettingsStore()
  const voiceActivation = useVoiceActivationStore()
  const voiceConnection = useVoiceConnectionStore()
  watch(() => voiceConnection.deafened, value => { soundsDeafened.value = value }, { immediate: true })
  const voiceNavigation = useVoiceNavigationStore()
  let shortcuts: VoiceShortcuts | null = null
  let soundRefresh: ReturnType<typeof setInterval> | null = null
  watch(() => voiceConnection.inputSelection, (selection) => { if (selection) audioSettings.observeInput(selection) })
  const cancelShortcuts = () => { shortcuts?.invalidate(); voiceActivation.shortcutStatus = '' }
  watch(() => voiceConnection.active, cancelShortcuts)
  watch(() => [voiceActivation.microphoneShortcut, voiceActivation.deafenShortcut], cancelShortcuts)
  const refreshDevices = () => { void loadAudioDevices() }
  onMounted(() => {
    void voiceSoundPreferences.select(accountId)
    legacySoundReview.select(accountId)
    soundRefresh = setInterval(() => { if (document.visibilityState === 'visible') void voiceSoundPreferences.refresh() }, 15000)
    voiceActivation.bindAccount?.(accountId)
    voiceConnection.bindControllerAccount?.(accountId)
    bindMicrophoneAccount(accountId || null)
    void audioSettings.loadProcessing(voiceConnection.setAudioProcessing)
    navigator.mediaDevices?.addEventListener?.('devicechange', refreshDevices)
    shortcuts = new VoiceShortcuts(window as unknown as VoiceShortcutSource, () => ({ microphone: voiceActivation.microphoneShortcut, deafen: voiceActivation.deafenShortcut }), {
      microphone: () => executeVoiceShortcut('microphone', voiceConnection, voiceActivation.mode),
      deafen: () => executeVoiceShortcut('deafen', voiceConnection, voiceActivation.mode),
    }, voiceActivation.announceShortcut)
    shortcuts.start(); window.addEventListener('blur', cancelShortcuts)
  })
  onBeforeUnmount(() => {
    soundQueue.clear(); void voiceSoundPreferences.select(null)
    legacySoundReview.select(null)
    if (soundRefresh) clearInterval(soundRefresh)
    bindMicrophoneAccount(null)
    stopJourneyRun()
    voiceConnection.bindControllerAccount?.('')
    navigator.mediaDevices?.removeEventListener?.('devicechange', refreshDevices)
    window.removeEventListener('blur', cancelShortcuts); shortcuts?.stop()
    shortcuts = null
    voiceActivation.unbindAccount()
  })

  async function loadAudioDevices(): Promise<void> {
    await audioSettings.loadInput(voiceConnection.setInputDevice)
    await audioSettings.load()
    await audioSettings.reconcileInput(voiceConnection.setInputDevice)
  }

  function findChannel(channelId: string | undefined): TopologyChannel | null {
    if (!channelId || !topologyStore.topology) return null
    return topologyStore.topology.categories.flatMap((category) => category.channels).find((channel) => channel.id === channelId) ?? null
  }

  const selectedChannelId = computed(() => {
    const surface = voiceNavigation.selectedSurface
    return surface.kind === 'TEXT' || surface.kind === 'VOICE' ? surface.channelId : null
  })
  const selectedChannel = computed(() => findChannel(selectedChannelId.value ?? undefined))
  const activeVoiceChannel = computed(() => findChannel(voiceConnection.active?.channelId))

  watch(() => topologyStore.topology, (topology) => {
    if (!topology) return
    const selected = voiceNavigation.selectedSurface
    if (selected.kind === 'DM') return
    const channels = topology.categories.flatMap(({ channels }) => channels)
    if (selected.kind === 'TEXT' || selected.kind === 'VOICE') {
      if (channels.some(({ id }) => id === selected.channelId)) return
      if (selected.kind === 'TEXT') voiceNavigation.clearSelectedText(selected.channelId)
      else voiceNavigation.clearSelectedVoice(selected.channelId)
    }
    const firstText = channels.find(({ kind }) => kind === 'TEXT')
    if (firstText) voiceNavigation.selectText(firstText.id)
  })

  function selectChannel(channel: TopologyChannel): void {
    voiceConnection.selectDisconnectChannel(channel.id)
    if (channel.kind === 'TEXT') voiceNavigation.selectText(channel.id)
    else voiceNavigation.selectVoice(channel.id)
  }

  function selectDirectMessage(directMessageId: string): void {
    voiceNavigation.selectDirectMessage(directMessageId)
  }

  const joinVoice=createWorkspaceVoiceJoin(audioSettings,voiceActivation,voiceConnection,voiceNavigation,leaveVoice)

  async function leaveVoice(): Promise<void> {
    await voiceActivation.stop(false)
    await voiceConnection.leave()
    if (!voiceConnection.active) voiceNavigation.clearActiveVoice()
  }

  async function startScreen(profile: ScreenProfile): Promise<void> {
    await voiceConnection.startScreen(profile)
  }

  async function selectAudioDevice(kind: AudioDeviceKind, deviceId: string): Promise<void> {
    if (kind === 'audioinput') await audioSettings.selectInput(deviceId, voiceConnection.setInputDevice)
    else await audioSettings.select(kind, deviceId, voiceConnection.switchAudioDevice)
  }

  return { activeVoiceChannel, audioSettings, loadAudioDevices, joinVoice, leaveVoice, selectAudioDevice, selectedChannel, selectedChannelId, selectChannel, selectDirectMessage, startScreen, topologyStore, voiceActivation, voiceConnection }
}
