import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(relativePath: string): string {
  try { return readFileSync(new URL(relativePath, import.meta.url), 'utf8') }
  catch { return '' }
}

describe('voice-room visual status and screen presentation', () => {
  it('gives mute and speaking states visible, explicit icon labels', () => {
    const status = source('./VoiceParticipantStatus.vue')
    expect(status).toContain('Микрофон выключен')
    expect(status).toContain('Микрофон недоступен')
    expect(status).toContain('Говорит')
    expect(status).toContain('is-speaking')
    expect(status).toContain('is-muted')
    expect(status).toContain('aria-hidden="true"')
  })

  it('presents the local participant with their nickname and speaking state', () => {
    const participants = source('./VoiceParticipantVolumes.vue')
    expect(participants).toContain(':speaking="selfSpeaking"')
    expect(participants).toContain('talking: selfSpeaking && !selfDeafened && !selfMicrophoneMuted && !selfMicrophoneUnavailable')
    expect(participants).not.toContain('`${name} · вы`')
    expect(participants).not.toContain('Это вы')
    expect(source('./connection_state/store.ts')).toContain('selfSpeaking: volume.selfSpeaking')
    expect(source('../workspace/WorkspaceMain.vue')).toContain(':self-speaking="voiceConnection.selfSpeaking"')
    expect(source('../conversation/ConversationPane.vue')).toContain(':self-speaking="selfSpeaking"')
  })

  it('shows the local deafened state distinctly from microphone mute', () => {
    const status = source('./VoiceParticipantStatus.vue')
    const cards = source('./VoiceParticipantVolumes.vue')
    expect(status).toContain('deafened')
    expect(status).toContain('Звук и микрофон выключены')
    expect(status).toContain('is-deafened')
    expect(cards).toContain(':deafened="selfDeafened"')
    expect(source('../workspace/WorkspaceMain.vue')).toContain(':self-deafened="voiceConnection.deafened"')
    expect(source('../conversation/ConversationPane.vue')).toContain(':self-deafened="selfDeafened"')
  })

  it('keeps voice connected and provides a direct return to the participant room', () => {
    const pane = source('../conversation/ConversationPane.vue')
    const connected = source('./VoiceRoomConnected.vue')
    const viewer = source('./ScreenViewer.vue')
    const members = source('../workspace/WorkspaceMembersPanel.vue')
    expect(pane).toContain(`(voiceIsActive || (screenPinned && activeVoiceChannel)) && voiceState !== 'LEAVING' && (screenViewerCards.length || selectedScreenStreamId || screenViewerEnded)`)
    expect(pane).toContain(`!voiceIsActive || voiceState === 'LEAVING' || !selectedScreenStreamId`)
    expect(pane).not.toContain('<VoiceParticipantStrip')
    expect(pane).toContain('voiceVolumeParticipants.length + 1')
    expect(connected).toContain(':participant-count="voiceVolumeParticipants.length + 1"')
    expect(connected).toContain('<VoiceRoomFooter')
    expect(pane).toContain('Голосовой канал · сейчас: ${voiceRoster.participants.length}')
    expect(pane).toContain('Голосовой канал · состав недоступен')
    expect(viewer).toContain('participantAudioMessage(deafened)')
    expect(viewer).toContain('К участникам')
    expect(viewer).toContain('<video ref="video" v-show="selectedId"')
    expect(source('../workspace/WorkspaceMembersPanel.vue')).toContain('selfMicrophoneUnavailable')
    expect(members).toContain('Микрофон выключен')
    expect(members).toContain('Говорит')
  })

  it('shows screen thumbnails in the room screen rail, not in participant cards', () => {
    const connected = source('./VoiceRoomConnected.vue')
    const rail = source('./ScreenViewerRail.vue')
    const participants = source('./VoiceParticipantVolumes.vue')

    expect(connected).toContain('<ScreenViewerRail')
    expect(connected).toContain(':cards="screenViewerCards"')
    expect(connected).toContain(':show-return-to-voice="false"')
    expect(connected).not.toContain('room-watch-primary')
    expect(rail).toContain('<h3>Демонстрации в канале</h3>')
    expect(rail).toContain('stream.thumbnailUrl')
    expect(participants).not.toContain('stream-thumbnail')
    expect(participants).not.toContain('thumbnailUrl')
  })

  it('distinguishes an unselected view from a selected but not joined voice room', () => {
    const panel = source('../workspace/WorkspaceMembersPanel.vue')
    expect(panel).toContain('selectedVoiceChannel')
    expect(panel).toContain('Подключитесь к каналу, чтобы увидеть его участников.')
    expect(panel).toContain('Участники гильдии')
    expect(source('../workspace/WorkspaceApp.vue')).toContain(':selected-voice-channel="selectedChannel?.kind === \'VOICE\' ? selectedChannel : null"')
  })

  it('exposes a fullscreen action and visible feedback on the stage', () => {
    const viewer = source('./ScreenViewer.vue')
    expect(viewer).toContain('Развернуть демонстрацию на весь экран')
    expect(viewer).toContain('Выйти из полноэкранного режима')
    expect(viewer).toContain('aria-live="polite"')
    expect(viewer).toContain('Развернуть на всю область')
    expect(viewer).toContain('Вернуть в окно канала')
    expect(viewer).toContain('update:expanded')
    expect(viewer).toContain('Escape')
    expect(source('../conversation/ConversationPane.vue')).toContain('voice-room--screen-expanded')
    expect(source('../conversation/ConversationPane.vue')).toContain(':disabled="!screenExpanded && !(miniVisible && miniPlayerTarget)"')
  })

  it('uses one setup dialog and selected profile from the room and persistent voice dock', () => {
    const pane = source('../conversation/ConversationPane.vue')
    const workspace = source('../workspace/WorkspaceApp.vue')
    const main = source('../workspace/WorkspaceMain.vue')
    const dock = source('./VoiceDock.vue')

    expect(source('./VoiceRoomControls.vue')).toContain("emit('startScreen', selectedScreenProfile)")
    expect(pane).toContain('@start-screen="emit(\'startScreen\', $event)"')
    expect(main).toContain(':selected-screen-profile="selectedScreenProfile"')
    expect(workspace).toContain('@start-screen="openScreenShareSetup"')
    expect(workspace).toContain('@start="confirmScreenShare"')
    expect(workspace).toContain(':screen-share-state="voiceConnection.screenState"')
    expect(workspace).toContain('@stop-screen="voiceConnection.stopScreen"')
    expect(dock).toContain('<VoiceRoomControls')
    expect(source('./VoiceRoomControls.vue')).toContain("transitioning || voiceState === 'RECONNECTING' || screenBusy")
  })

  it('sizes video to the stage without cropping and preserves compact roster access', () => {
    const styles = source('../design/voice.css')
    const shell = source('../design/responsive_shell.css')
    expect(styles).toContain('object-fit: contain')
    expect(styles).toContain('.screen-stage:fullscreen')
    expect(styles).toContain('.voice-room--screen-expanded')
    expect(styles).toContain('position: fixed;')
    expect(styles).toContain('.voice-participant-strip')
    expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-small) minmax(0, 1fr)')
    expect(shell).toContain('width: min(320px, calc(100% - 32px))')
  })
})
