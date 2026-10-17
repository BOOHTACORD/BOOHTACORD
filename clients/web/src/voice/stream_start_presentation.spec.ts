import { describe, expect, it } from 'vitest'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'

import VoiceDock from './VoiceDock.vue'
import VoiceParticipantVolumes from './VoiceParticipantVolumes.vue'
import StreamStartSoundSetting from './StreamStartSoundSetting.vue'
import { streamStartChime, streamStartNotice } from './stream_start_runtime'

describe('new screen presentation', () => {
  it('marks a remote participant live and keeps the personal sound switch in audio settings', async () => {
    streamStartChime.setEnabled(true)
    const participants = await renderToString(createSSRApp(VoiceParticipantVolumes, {
      error: null, participants: [{ id: 'alice', accountId: 'alice', name: 'Алиса', volume: 100, speaking: false, microphoneMuted: false }],
      screenStreams: [{ id: 'alice:screen', participantId: 'alice', participantName: 'Алиса', hasAudio: true }],
      selectedScreenStreamId: null, selfName: 'Оля', selfDeafened: false, selfMicrophoneMuted: false,
      selfMicrophoneUnavailable: false, selfSpeaking: false,
    }))
    const dock = await renderToString(createSSRApp(VoiceDock, {
      channel: null, activeSession: true, error: null, activationMode: 'VAD', deafened: false,
      deafenChanging: false, microphoneMuted: false, microphonePermissionDenied: false, state: 'CONNECTED',
    }))

    expect(participants).toContain('ЭФИР')
    expect(participants).toContain('Участник показывает экран')
    const soundSetting = await renderToString(createSSRApp(StreamStartSoundSetting))
    expect(dock).not.toContain('Звук начала трансляций включён')
    expect(soundSetting).toContain('Звук начала трансляций включён')
    expect(soundSetting).toContain('aria-checked="true"')

    streamStartNotice.value = true
    streamStartChime.setEnabled(false)
    try {
      const silentDock = await renderToString(createSSRApp(VoiceDock, {
        channel: null, activeSession: true, error: null, activationMode: 'VAD', deafened: false,
        deafenChanging: false, microphoneMuted: false, microphonePermissionDenied: false, state: 'CONNECTED',
      }))
      const silentSetting = await renderToString(createSSRApp(StreamStartSoundSetting))
      expect(silentDock).not.toContain('Звук начала трансляций выключен')
      expect(silentSetting).toContain('Звук начала трансляций выключен')
      expect(silentSetting).toContain('aria-checked="false"')
      expect(silentDock).not.toContain('В канале началась демонстрация экрана')
    } finally {
      streamStartNotice.value = false
      streamStartChime.setEnabled(true)
    }
  })
})
