import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(relativePath: string): string {
  try { return readFileSync(new URL(relativePath, import.meta.url), 'utf8') }
  catch { return '' }
}

describe('voice participant screen actions', () => {
  it('keeps the participant room visible until a real screen is selected', () => {
    const pane = source('../conversation/ConversationPane.vue')

    expect(pane).toContain('screenViewerCards.length || selectedScreenStreamId || screenViewerEnded')
    expect(pane).toContain('v-show="selectedScreenStreamId !== null"')
    expect(pane).toContain(`!voiceIsActive || voiceState === 'LEAVING' || !selectedScreenStreamId`)
    expect(pane).toContain('@watch-screen="watchScreen"')
    expect(pane).toContain('ref="screenViewerRef"')
    expect(pane).toContain('@clear="clearScreenPreview"')
    expect(pane).toContain('dismissLocalPreview()')
  })

  it('shows screen share and watch affordances only on participants with a real stream', () => {
    const participants = source('./VoiceParticipantVolumes.vue')
    const styles = source('../design/voice_participant_screens.css')

    expect(participants).toContain('screenForParticipant')
    expect(participants).toContain('participant-share-badge')
    expect(participants).toContain('Смотреть экран')
    expect(participants).toContain('aria-pressed')
    expect(styles).toContain('.participant-share-badge')
    expect(styles).toContain('.participant-watch')
  })

  it('resolves a watch action by the verified LiveKit participant identity', async () => {
    const { findParticipantScreen } = await import('./find_participant_screen')
    const streams = [
      { id: 'alice:screen', participantId: 'alice', participantName: 'Алиса', hasAudio: true },
      { id: 'bob:screen', participantId: 'bob', participantName: 'Боб', hasAudio: false },
    ]

    expect(findParticipantScreen(streams, 'bob')?.id).toBe('bob:screen')
    expect(findParticipantScreen(streams, 'offline')).toBeNull()
  })
})
