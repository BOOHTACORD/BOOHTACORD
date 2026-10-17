import { effectScope, nextTick, reactive } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import type { TopologyChannel } from '../channel/topology_client'
import { useConversationScreenState } from './use_conversation_screen_state'
import type { ScreenViewerCard } from './screen_viewer_controller'

function channel(id: string, kind: 'TEXT' | 'VOICE'): TopologyChannel {
  return { id, kind, name: id, position: 0, admissionClosed: false }
}

function selectedScreen(): ScreenViewerCard {
  return { hasAudio: true, id: 'remote:screen', participantId: 'remote', participantName: 'Участник', isLocal: false }
}

describe('pinned screen mini player state', () => {
  it('stops showing the viewer after navigation unless the user pinned it', () => {
    const props = reactive({
      visible: false,
      channel: channel('text', 'TEXT') as TopologyChannel | null,
      activeVoiceChannel: channel('voice', 'VOICE') as TopologyChannel | null,
      directMessage: null,
      selectedScreenStreamId: 'remote:screen' as string | null,
      screenViewerCards: [selectedScreen()],
      screenViewerEnded: false,
    })
    const scope = effectScope()
    let state!: ReturnType<typeof useConversationScreenState>
    scope.run(() => { state = useConversationScreenState(props) })

    expect(state.screenPinned.value).toBe(false)
    expect(state.keepVoiceRoom.value).toBe(false)
    expect(state.miniVisible.value).toBe(false)
    scope.stop()
  })

  it('reuses the pinned viewer reference from full view through mini view and back', async () => {
    const voice = channel('voice', 'VOICE')
    const props = reactive({
      visible: true,
      channel: voice as TopologyChannel | null,
      activeVoiceChannel: voice as TopologyChannel | null,
      directMessage: null,
      selectedScreenStreamId: 'remote:screen' as string | null,
      screenViewerCards: [selectedScreen()],
      screenViewerEnded: false,
    })
    const scope = effectScope()
    let state!: ReturnType<typeof useConversationScreenState>
    scope.run(() => { state = useConversationScreenState(props) })
    const viewer = { selectStream: vi.fn() }
    state.screenViewerRef.value = viewer
    state.screenPinned.value = true

    expect(state.keepVoiceRoom.value).toBe(true)
    expect(state.miniVisible.value).toBe(false)
    state.screenExpanded.value = true
    props.channel = channel('text', 'TEXT')
    props.visible = false
    await nextTick()
    expect(state.keepVoiceRoom.value).toBe(true)
    expect(state.miniVisible.value).toBe(true)
    expect(state.screenExpanded.value).toBe(false)
    expect(state.screenViewerRef.value).toBe(viewer)
    expect(props.selectedScreenStreamId).toBe('remote:screen')

    props.channel = voice
    props.visible = true
    await nextTick()
    expect(state.keepVoiceRoom.value).toBe(true)
    expect(state.miniVisible.value).toBe(false)
    expect(state.screenViewerRef.value).toBe(viewer)
    expect(viewer.selectStream).not.toHaveBeenCalled()
    scope.stop()
  })

  it('expands a pinned chat viewer and returns to the same mini player without reselecting', async () => {
    const props = reactive({ visible: true, channel: channel('text', 'TEXT'), activeVoiceChannel: channel('voice', 'VOICE'), directMessage: null,
      selectedScreenStreamId: 'remote:screen' as string | null, screenViewerCards: [selectedScreen()], screenViewerEnded: false })
    const scope = effectScope()
    let state!: ReturnType<typeof useConversationScreenState>
    scope.run(() => { state = useConversationScreenState(props) })
    state.screenPinned.value = true
    await nextTick()
    state.screenExpanded.value = true
    await nextTick()
    expect(state.miniVisible.value).toBe(false)
    expect(state.keepVoiceRoom.value).toBe(true)
    expect(state.screenExpanded.value).toBe(true)
    state.screenExpanded.value = false
    await nextTick()
    expect(state.miniVisible.value).toBe(true)
    props.selectedScreenStreamId = null
    await nextTick()
    expect(state.screenPinned.value).toBe(false)
    expect(state.screenExpanded.value).toBe(false)
    scope.stop()
  })

  it('unpins and removes the mini viewer after stop, logout or lease revoke', async () => {
    const props = reactive({
      visible: false,
      channel: channel('text', 'TEXT') as TopologyChannel | null,
      activeVoiceChannel: channel('voice', 'VOICE') as TopologyChannel | null,
      directMessage: null,
      selectedScreenStreamId: 'remote:screen' as string | null,
      screenViewerCards: [selectedScreen()],
      screenViewerEnded: false,
    })
    const scope = effectScope()
    let state!: ReturnType<typeof useConversationScreenState>
    scope.run(() => { state = useConversationScreenState(props) })
    state.screenPinned.value = true
    expect(state.miniVisible.value).toBe(true)

    state.screenExpanded.value = true
    props.activeVoiceChannel = null
    await nextTick()
    expect(state.screenExpanded.value).toBe(false)
    expect(state.screenPinned.value).toBe(false)
    props.selectedScreenStreamId = null
    await nextTick()
    expect(state.screenPinned.value).toBe(false)
    expect(state.keepVoiceRoom.value).toBe(false)
    expect(state.miniVisible.value).toBe(false)
    scope.stop()
  })
})
