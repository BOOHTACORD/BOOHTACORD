<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import type { TopologyChannel } from '../channel/topology_client'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { avatarInitials } from '../design/avatar_initials'
import { useMemberDirectory } from '../identity/member_directory'
import type { MemberPresence } from '../identity/profile_client'
import type { VoiceVolumeParticipant } from '../voice/voice_volume_controls'
import VoiceParticipantStatus from '../voice/VoiceParticipantStatus.vue'
import GuildPresenceGroup from './GuildPresenceGroup.vue'
import MemberPopover from './MemberPopover.vue'
import { groupMembersByPresence } from './member_presence'

const props = defineProps<{ activeVoiceChannel: TopologyChannel | null; selectedVoiceChannel: TopologyChannel | null; participants: VoiceVolumeParticipant[]; presenceResolver: (userID: string, fallback: MemberPresence) => MemberPresence; role: 'MEMBER' | 'ADMINISTRATOR'; accountID?: string; selfMicrophoneMuted: boolean; selfMicrophoneUnavailable: boolean; selfName: string | null; open: boolean; modal: boolean }>()
const emit = defineEmits<{ openDM: [userID: string]; setVolume: [participantID: string, volume: number]; memberCount: [count: number] }>()
const directory = useMemberDirectory()
const guildMembers = computed(() => directory.members)
const memberCursor = computed(() => directory.cursor)
const membersLoading = computed(() => directory.loading)
const membersError = computed(() => directory.error)
const presenceGroups = computed(() => groupMembersByPresence(guildMembers.value.map((member) => ({ ...member, presence: props.presenceResolver(member.user_id, member.presence) }))))
const selectedID = ref<string | null>(null)
const openedFromVoiceRoster = ref(false)
const trigger = ref<HTMLButtonElement | null>(null)
const selectedVoiceParticipant = computed(() => props.participants.find((participant) => participant.accountId === selectedID.value) ?? null)
const voiceRoomVisible = computed(() => Boolean(props.selectedVoiceChannel && props.activeVoiceChannel?.id === props.selectedVoiceChannel.id))
const visibleVoiceChannel = computed(() => props.selectedVoiceChannel)
const memberCount = computed(() => props.selectedVoiceChannel ? voiceRoomVisible.value ? props.participants.length + 1 : '—' : memberCursor.value ? '—' : guildMembers.value.length)

async function loadRoster(cursor?: string): Promise<void> {
  if (directory.loading) return
  if (cursor) await directory.loadNext()
  else await directory.refresh()
  if (!directory.cursor) emit('memberCount', directory.members.length)
}
function openProfile(userID: string, event: MouseEvent): void {
  const button = event.currentTarget as HTMLButtonElement
  trigger.value = button
  openedFromVoiceRoster.value = Boolean(button.closest('.members-voice-roster'))
  selectedID.value = userID
}
function closeProfile(restoreFocus = true): void {
  selectedID.value = null
  if (restoreFocus) void nextTick(() => trigger.value?.focus())
}
function setVolume(volume: number): void { if (selectedVoiceParticipant.value) emit('setVolume', selectedVoiceParticipant.value.id, volume) }
function voiceStateLabel(muted: boolean, speaking: boolean, unavailable = false): string {
  if (unavailable) return 'Микрофон недоступен'
  if (muted) return 'Микрофон выключен'
  return speaking ? 'Говорит' : 'В голосовом канале'
}
watch(() => props.open, () => closeProfile(false))
watch(voiceRoomVisible, (visible) => { if (!visible && openedFromVoiceRoster.value) closeProfile(false) })
onMounted(() => { if (!props.selectedVoiceChannel) void loadRoster() })
</script>

<template>
  <aside id="members-panel" class="members members-panel" :class="{ 'is-open': open, 'has-popover': Boolean(selectedID) }" :role="modal && !selectedID ? 'dialog' : undefined" :aria-modal="modal && !selectedID ? 'true' : undefined" aria-label="Участники" tabindex="-1" data-testid="members-panel">
    <h2 class="members-heading">Участники <span>{{ membersLoading && !guildMembers.length ? '—' : memberCount }}</span></h2>
    <p v-if="visibleVoiceChannel" class="members-summary">Голосовой канал · {{ visibleVoiceChannel.name }}</p>
    <p v-if="selectedVoiceChannel && !voiceRoomVisible" class="members-empty">{{ activeVoiceChannel ? `Вы подключены к «${activeVoiceChannel.name}». Перенесите подключение, чтобы увидеть участников этого канала.` : 'Подключитесь к каналу, чтобы увидеть его участников.' }}</p>
    <section v-if="voiceRoomVisible" class="members-voice-roster" aria-label="Подключённые к голосовому каналу" :inert="Boolean(selectedID) && modal">
      <h3 class="members-group">В голосовом канале · {{ participants.length + 1 }}</h3>
      <ul class="member-list">
        <li class="member-card member member-self"><span class="member-avatar" :style="{ backgroundColor: avatarBackground(accountID ?? selfName ?? 'Вы'), color: avatarForeground(accountID ?? selfName ?? 'Вы') }" aria-hidden="true">{{ avatarInitials(selfName ?? 'Вы') }}</span><span class="member-copy"><span :title="selfName ?? 'Вы'" class="member-name">{{ selfName || 'Вы' }}</span></span><VoiceParticipantStatus compact :microphone-muted="selfMicrophoneMuted" :microphone-unavailable="selfMicrophoneUnavailable" /></li>
        <li v-for="participant in participants" :key="participant.id">
          <button class="member-card member" :class="{ 'member-speaking': participant.speaking }" type="button" :title="`${participant.name || 'Участник'} · ${voiceStateLabel(participant.microphoneMuted, participant.speaking)}`" :disabled="!participant.accountId" :aria-label="`Профиль: ${participant.name || 'Участник'} · ${voiceStateLabel(participant.microphoneMuted, participant.speaking)}`" @click="participant.accountId && openProfile(participant.accountId, $event)">
            <span class="member-avatar" :style="{ backgroundColor: avatarBackground(participant.accountId ?? participant.id), color: avatarForeground(participant.accountId ?? participant.id) }" aria-hidden="true">{{ avatarInitials(participant.name) }}</span><span class="member-copy"><span class="member-name">{{ participant.name || 'Участник' }}</span></span><VoiceParticipantStatus compact :microphone-muted="participant.microphoneMuted" :speaking="participant.speaking" />
          </button>
        </li>
      </ul>
    </section>
    <section v-if="!selectedVoiceChannel" class="members-guild-roster" aria-label="Участники гильдии" :inert="Boolean(selectedID) && modal">
      <p v-if="membersError" class="members-error" role="alert">{{ membersError }} <button type="button" @click="loadRoster()">Повторить</button></p>
      <p v-else-if="membersLoading && !guildMembers.length" class="members-empty" aria-live="polite">Загружаем участников…</p>
      <p v-else-if="!guildMembers.length" class="members-empty">В гильдии пока нет участников.</p>
      <div v-else class="members-presence-groups">
        <GuildPresenceGroup title="В сети" :members="presenceGroups.online" @open="openProfile" />
        <GuildPresenceGroup title="Не в сети" :members="presenceGroups.offline" @open="openProfile" />
        <GuildPresenceGroup title="Статус неизвестен" :members="presenceGroups.unknown" @open="openProfile" />
      </div>
      <button v-if="memberCursor && !membersError" class="members-more" type="button" :disabled="membersLoading" @click="loadRoster(memberCursor)">{{ membersLoading ? 'Загружаем…' : 'Показать ещё' }}</button>
    </section>
    <div v-if="selectedID && modal" class="member-sheet-scrim" aria-hidden="true" @click="closeProfile()" />
    <MemberPopover v-if="selectedID" :key="selectedID" :member-i-d="selectedID" :self="selectedID === props.accountID" :viewer-role="props.role" :same-voice="Boolean(openedFromVoiceRoster && activeVoiceChannel && selectedVoiceParticipant)" :volume="selectedVoiceParticipant?.volume ?? 100" :anchor="trigger" :voice-status="openedFromVoiceRoster && selectedVoiceParticipant ? voiceStateLabel(selectedVoiceParticipant.microphoneMuted, selectedVoiceParticipant.speaking) : undefined" :modal="modal" @close="closeProfile" @open-d-m="emit('openDM', $event)" @set-volume="setVolume" />
  </aside>
</template>
