<script setup lang="ts">
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { avatarInitials } from '../design/avatar_initials'
import type { GuildMember, MemberPresence } from '../identity/profile_client'
import type { GuildVoicePresence } from './guild_voice_presence'

const props = defineProps<{ title: string; members: GuildMember[]; voicePresence?: ReadonlyMap<string, GuildVoicePresence> }>()
const emit = defineEmits<{ open: [userID: string, event: MouseEvent] }>()
function statusLabel(presence: MemberPresence): string {
  if (presence === 'online') return 'В сети'
  if (presence === 'offline') return 'Не в сети'
  return 'Статус неизвестен'
}
function memberDescription(member: GuildMember): string {
  const labels = [member.display_name, statusLabel(member.presence)]
  const voice = props.voicePresence?.get(member.user_id)
  if (voice) {
    labels.push(`В голосовом канале «${voice.channelName}»`)
    if (voice.screenSharing) labels.push('Транслирует экран')
  }
  return labels.join(' · ')
}
</script>

<template>
  <section v-if="members.length" class="members-presence-group">
    <h3 class="members-group">{{ title }} — {{ members.length }}</h3>
    <ul class="member-list">
      <li v-for="member in members" :key="member.user_id">
        <button class="member-card member" :class="`member--${member.presence}`" type="button" :title="memberDescription(member)" :aria-label="`Профиль: ${memberDescription(member)}`" @click="emit('open', member.user_id, $event)">
          <span class="member-avatar-wrap">
            <img v-if="member.avatar_url" class="member-avatar" :src="member.avatar_url" alt="">
            <span v-else class="member-avatar" :style="{ backgroundColor: avatarBackground(member.user_id), color: avatarForeground(member.user_id) }" aria-hidden="true">{{ avatarInitials(member.display_name) }}</span>
            <span class="member-presence-dot" :class="`member-presence-dot--${member.presence}`" aria-hidden="true"></span>
          </span>
          <span class="member-copy"><span class="member-name">{{ member.display_name }}</span><span v-if="props.voicePresence?.get(member.user_id)" class="member-voice-presence" :class="{ 'is-streaming': props.voicePresence.get(member.user_id)?.screenSharing }" data-testid="member-voice-presence"><svg class="member-voice-icon" :data-kind="props.voicePresence.get(member.user_id)?.screenSharing ? 'stream' : 'voice'" data-testid="member-voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path v-if="props.voicePresence.get(member.user_id)?.screenSharing" d="M4 5h16v11H4zM9 20h6m-3-4v4" /><template v-else><path d="M3 10v4h4l5 4V6l-5 4H3Z" /><path d="M16 9a5 5 0 0 1 0 6M19 6a9 9 0 0 1 0 12" /></template></svg><span>Голосовой канал · {{ props.voicePresence.get(member.user_id)?.channelName }}</span></span></span>
        </button>
      </li>
    </ul>
  </section>
</template>
