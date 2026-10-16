<script setup lang="ts">
import { computed } from 'vue'
import type { VoiceActivationMode } from './activation_store'
import type { VoiceConnectionState } from './connection_store'
import { voiceRoomSummary } from './voice_room_copy'
const props = withDefaults(defineProps<{ channelName: string; state: VoiceConnectionState; activationMode: VoiceActivationMode; participantCount?: number; screenCount?: number }>(), { participantCount: 1, screenCount: 0 })
const status = computed(() => props.state === 'JOINING' ? 'Подключаемся…' : props.state === 'RECONNECTING' ? 'Восстанавливаем связь…' : props.state === 'LEAVING' ? 'Завершаем голосовое подключение…' : props.state === 'ERROR' ? 'Ошибка голосового подключения' : props.state === 'LISTENER' ? 'Режим слушателя' : 'В голосе')
</script>

<template>
  <footer class="voice-room-footer" :aria-label="`Голосовое подключение: ${channelName}`" data-testid="voice-room-footer">
    <div class="voice-room-footer-copy"><p role="status" aria-atomic="true">{{ status }}</p><small v-if="state !== 'LEAVING'">{{ voiceRoomSummary(participantCount, screenCount) }}</small></div>
  </footer>
</template>
