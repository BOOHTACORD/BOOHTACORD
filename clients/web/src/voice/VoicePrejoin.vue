<script setup lang="ts">
import DisconnectNotice from './disconnect_notice/Notice.vue'
import TransferConfirmation from './controller_ownership/TransferConfirmation.vue'
import type { VoiceDisconnectNotice } from './disconnect_notice/model'
import type { VoiceConnectionState } from './connection_store'
import type { VoiceJoinMode } from './livekit_gateway'
import VoiceRoomRoster from './VoiceRoomRoster.vue'
import type { VoiceRoomRoster as RoomRoster } from './voice_roster_client'
import { retryVoiceRoster } from './roster_status/retry_action'

defineProps<{ channelId: string; voiceError: string | null; voiceState: VoiceConnectionState; voiceTransferRequired: boolean; notice?: VoiceDisconnectNotice | null; roster?: RoomRoster | null; rosterError?: string | null }>()
const emit = defineEmits<{ join: [channelId: string, transfer?: boolean, joinMode?: VoiceJoinMode]; transfer: [channelId: string] }>()
</script>

<template>
  <div class="voice-prejoin">
    <article class="voice-prejoin-card" aria-labelledby="voice-prejoin-title">
      <span class="voice-prejoin-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M12 3a3 3 0 0 0-3 3v5a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Zm-7 8a7 7 0 0 0 14 0M12 18v3m-4 0h8" /></svg></span>
      <h3 id="voice-prejoin-title" aria-live="polite" aria-atomic="true">{{ voiceState === 'JOINING' ? 'Входим в голос…' : 'Войти в голос' }}</h3>
      <VoiceRoomRoster v-if="roster" compact :roster="roster" />
      <p v-if="roster && rosterError" class="state state-error" role="status">Состав устарел. Восстанавливаем соединение.</p>
      <p v-else-if="rosterError" class="state state-error" role="status">Не удалось обновить состав комнаты. Повторяем попытку.</p>
      <p v-else-if="!roster" class="state" role="status">Проверяем, кто сейчас в комнате…</p>
      <button v-if="rosterError" class="gc-button gc-button--secondary" type="button" aria-label="Повторить загрузку состава голосовой комнаты" @click="retryVoiceRoster()">Повторить попытку</button>
      <DisconnectNotice v-if="notice" :notice="notice" />
      <p v-else-if="voiceError" class="state state-error" role="alert">{{ voiceError }}</p>
      <TransferConfirmation v-if="voiceTransferRequired" @confirm="emit('join', channelId, true, $event)" />
      <div v-else class="voice-prejoin-actions">
        <button class="gc-button gc-button--primary" type="button" :disabled="voiceState === 'JOINING' || voiceState === 'LEAVING' || notice?.reconnectAllowed === false" @click="emit('join', channelId)">{{ voiceState === 'JOINING' ? 'Подключаемся…' : 'Войти' }}</button>
        <button class="gc-button gc-button--secondary" type="button" :disabled="voiceState === 'JOINING' || voiceState === 'LEAVING' || notice?.reconnectAllowed === false" @click="emit('join', channelId, false, 'listener')">Без микрофона</button>
      </div>
    </article>
  </div>
</template>
