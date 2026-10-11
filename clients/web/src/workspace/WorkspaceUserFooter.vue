<script setup lang="ts">
import { avatarInitials } from '../design/avatar_initials'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
defineProps<{ role: 'MEMBER' | 'ADMINISTRATOR'; displayName?: string; avatarURL?: string; accountID?: string; online?: boolean }>()
const emit = defineEmits<{ openSettings: []; openProfile: [] }>()
</script>

<template>
  <footer class="user-footer">
    <button class="user-footer-profile" type="button" aria-label="Открыть настройки профиля" @click="emit('openProfile')">
      <span class="user-footer-identity">
      <img v-if="avatarURL" class="user-footer-avatar" :src="avatarURL" alt="">
      <span v-else class="user-footer-avatar" :style="{ backgroundColor: avatarBackground(accountID ?? displayName ?? 'Вы'), color: avatarForeground(accountID ?? displayName ?? 'Вы') }" aria-hidden="true">{{ avatarInitials(displayName, 'В') }}</span>
      <span v-if="online" class="user-footer-presence" role="img" aria-label="В сети" />
      </span>
      <span class="username"><span class="user-footer-name">{{ displayName || 'Профиль' }}</span><small>{{ role === 'ADMINISTRATOR' ? 'Администратор' : 'Участник' }}</small></span>
    </button>
    <button class="user-footer-settings" type="button" aria-label="Настройки аудио" title="Настройки аудио" @click="emit('openSettings')">
      <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33h-.07a1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.08a1.65 1.65 0 0 0-1-1.51h-.07a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82v-.07a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.08a1.65 1.65 0 0 0 1.51-1v-.07a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33h.07a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.08a1.65 1.65 0 0 0 1 1.51h.07a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82v.07a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.08a1.65 1.65 0 0 0-1.51 1z" /></svg>
    </button>
  </footer>
</template>
