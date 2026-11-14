<script setup lang="ts">
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { watch } from 'vue'
import { useAuthorDirectory } from '../identity/author_directory'
import VoiceParticipantStatus from './VoiceParticipantStatus.vue'
import type { VoiceRoomRoster } from './voice_roster_client'

const props = defineProps<{ roster: VoiceRoomRoster; compact?: boolean }>()
const authors = useAuthorDirectory()
watch(() => props.roster.participants.map((member) => member.accountId), (ids) => {
  ids.forEach((id) => { void authors.ensure(id) })
}, { immediate: true })

function initial(name: string): string { return Array.from(name.trim())[0]?.toLocaleUpperCase('ru-RU') || 'У' }
</script>

<template>
  <section class="voice-roster-preview" :class="{ 'voice-roster-preview--compact': compact }" :aria-label="roster.participants.length ? `Сейчас в канале: ${roster.participants.length}` : 'Голосовой канал пуст'">
    <p class="voice-roster-heading">{{ roster.participants.length ? `Сейчас в канале: ${roster.participants.length}` : 'Участники голосового канала' }}</p>
    <ul v-if="roster.participants.length" class="voice-roster-members">
      <li v-for="member in roster.participants" :key="member.accountId" class="voice-roster-member">
        <span class="voice-member-avatar" :style="{ backgroundColor: avatarBackground(member.accountId), color: avatarForeground(member.accountId) }" aria-hidden="true"><img v-if="authors.avatarUrl(member.accountId)" :src="authors.avatarUrl(member.accountId)" alt=""><template v-else>{{ initial(member.displayName) }}</template></span>
        <span class="voice-member-name">{{ member.displayName }}</span>
        <span v-if="member.screenSharing" class="voice-roster-live" role="img" aria-label="Показывает экран" title="Показывает экран">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5h16v11H4zM9 20h6m-3-4v4" /></svg><span>Идёт трансляция</span>
        </span>
        <VoiceParticipantStatus compact :deafened="member.deafened" :microphone-muted="member.microphoneMuted ?? true" />
      </li>
    </ul>
    <p v-else class="voice-roster-empty">Пока никого нет.</p>
  </section>
</template>
