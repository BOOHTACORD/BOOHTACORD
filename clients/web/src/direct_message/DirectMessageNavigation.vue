<script setup lang="ts">
import { vActionHint } from '../shared/action_hint/directive'
import { computed, onMounted } from 'vue'
import { useMemberDirectory } from '../identity/member_directory'
import type { DirectMessageListItem } from './direct_message_client'
import DirectMessageStarter from './DirectMessageStarter.vue'

const props = defineProps<{
  directMessages: DirectMessageListItem[]
  error: string | null
  loading: boolean
  selectedDirectMessageId?: string
}>()

const emit = defineEmits<{ select: [directMessageId: string]; open: [directMessageId: string] }>()
const memberDirectory = useMemberDirectory()
const members = computed(() => memberDirectory.byId)
onMounted(() => { void memberDirectory.refresh() })

</script>

<template>
  <nav class="direct-message-navigation" aria-label="Личные сообщения">
    <h2>
      СООБЩЕНИЯ
      <DirectMessageStarter
        v-if="props.loading || props.error || props.directMessages.length"
        @open="emit('open', $event)"
      />
    </h2>
    <p v-if="props.loading" class="empty-category" aria-live="polite">Загружаем диалоги…</p>
    <p v-else-if="props.error" class="empty-category state-error" role="alert">{{ props.error }}</p>
    <div v-else-if="!props.directMessages.length" class="direct-message-empty">
      <p>Начните личный разговор с участником.</p>
      <DirectMessageStarter prominent @open="emit('open', $event)" />
    </div>
    <button
      v-action-hint="directMessage.otherParticipantDisplayName"
      v-for="directMessage in props.directMessages"
      :key="directMessage.id"
      class="channel-button"
      :class="{ selected: props.selectedDirectMessageId === directMessage.id }"
      :aria-current="props.selectedDirectMessageId === directMessage.id ? 'page' : undefined"
      type="button"
      @click="emit('select', directMessage.id)"
    >
      <span class="dm-avatar" :class="`dm-avatar--${directMessage.otherParticipantDisplayName.toLocaleLowerCase('ru-RU')}`" aria-hidden="true">{{ directMessage.otherParticipantDisplayName.slice(0, 2).toLocaleUpperCase('ru-RU') }}</span>
      <span class="dm-presence-dot" :class="{ 'is-online': members[directMessage.otherParticipantId]?.presence === 'online' }" aria-hidden="true" />
      <span class="dm-identity"><span class="channel-name">{{ directMessage.otherParticipantDisplayName }}</span><small>{{ members[directMessage.otherParticipantId]?.presence === 'online' ? 'В сети' : members[directMessage.otherParticipantId]?.presence === 'offline' ? 'Не в сети' : 'Статус неизвестен' }}</small></span>
      <span v-if="directMessage.unreadCount" class="channel-state" :aria-label="`Непрочитанных личных сообщений: ${directMessage.unreadCount}`">{{ directMessage.unreadCount }}</span>
      <span v-if="directMessage.mentionCount" class="channel-state" :aria-label="`Упоминаний в личном диалоге: ${directMessage.mentionCount}`">@{{ directMessage.mentionCount }}</span>
    </button>
  </nav>
</template>
