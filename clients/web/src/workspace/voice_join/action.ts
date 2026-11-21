import type { useAudioSettingsStore } from '../../voice/audio_settings_store'
import type { useVoiceActivationStore } from '../../voice/activation_store'
import type { useVoiceConnectionStore } from '../../voice/connection_store'
import type { useVoiceNavigationStore } from '../../voice/navigation_store'
import type { VoiceJoinMode } from '../../voice/livekit_gateway'
import { streamStartChime } from '../../voice/stream_start_runtime'
import { journeyRecorder } from '../../telemetry/journey_intervals/runtime'
export function createWorkspaceVoiceJoin(audioSettings:ReturnType<typeof useAudioSettingsStore>,voiceActivation:ReturnType<typeof useVoiceActivationStore>,voiceConnection:ReturnType<typeof useVoiceConnectionStore>,voiceNavigation:ReturnType<typeof useVoiceNavigationStore>,leaveVoice:()=>Promise<void>) {
  return async(channelId:string,transfer=false,joinMode:VoiceJoinMode='with-microphone'):Promise<void>=>{
    const finish=journeyRecorder.begin('voice_connect')
    try {
      const activeChannelId=voiceConnection.active?.channelId
      streamStartChime.activate()
      if(activeChannelId&&activeChannelId!==channelId) await leaveVoice()
      await audioSettings.loadInput(voiceConnection.setInputDevice)
      await audioSettings.loadProcessing(voiceConnection.setAudioProcessing)
      await voiceConnection.join(channelId,transfer,voiceActivation.mode==='PTT'?'listener':joinMode)
      if(voiceConnection.active&&voiceActivation.mode==='PTT') await voiceActivation.setMode('PTT')
      if(voiceConnection.active) voiceNavigation.confirmVoiceConnected(voiceConnection.active.channelId)
      finish(voiceConnection.active?.channelId===channelId?'completed':'failed')
    } catch(cause){finish('failed');throw cause}
  }
}
