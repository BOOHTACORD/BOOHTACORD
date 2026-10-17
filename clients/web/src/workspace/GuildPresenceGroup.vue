<script setup lang="ts">
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { avatarInitials } from '../design/avatar_initials'
import type { GuildMember, MemberPresence } from '../identity/profile_client'

defineProps<{ title: string; members: GuildMember[] }>()
const emit = defineEmits<{ open: [userID: string, event: MouseEvent] }>()
function statusLabel(presence: MemberPresence): string {
  if (presence === 'online') return 'В сети'
  if (presence === 'offline') return 'Не в сети'
  return 'Статус неизвестен'
}
</script>

<template>
  <section v-if="members.length" class="members-presence-group">
    <h3 class="members-group">{{ title }} — {{ members.length }}</h3>
    <ul class="member-list">
      <li v-for="member in members" :key="member.user_id">
        <button class="member-card member" :class="`member--${member.presence}`" type="button" :title="`${member.display_name} · ${statusLabel(member.presence)}`" :aria-label="`Профиль: ${member.display_name} · ${statusLabel(member.presence)}`" @click="emit('open', member.user_id, $event)">
          <span class="member-avatar-wrap">
            <img v-if="member.avatar_url" class="member-avatar" :src="member.avatar_url" alt="">
            <span v-else class="member-avatar" :style="{ backgroundColor: avatarBackground(member.user_id), color: avatarForeground(member.user_id) }" aria-hidden="true">{{ avatarInitials(member.display_name) }}</span>
            <span class="member-presence-dot" :class="`member-presence-dot--${member.presence}`" aria-hidden="true"></span>
          </span>
          <span class="member-copy"><span class="member-name">{{ member.display_name }}</span></span>
        </button>
      </li>
    </ul>
  </section>
</template>
