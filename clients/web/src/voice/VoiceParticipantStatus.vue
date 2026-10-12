<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{ compact?: boolean; deafened?: boolean; microphoneMuted: boolean; microphoneUnavailable?: boolean; speaking?: boolean }>(), { compact: false, deafened: false, microphoneUnavailable: false, speaking: false })
const isSpeaking = computed(() => props.speaking && !props.microphoneMuted && !props.microphoneUnavailable && !props.deafened)
const state = computed(() => props.deafened ? 'Звук и микрофон выключены' : props.microphoneUnavailable ? 'Микрофон недоступен' : props.microphoneMuted ? 'Микрофон выключен' : isSpeaking.value ? 'Говорит' : 'В голосовом канале')
</script>

<template>
  <span role="img" class="voice-person-state" :class="{ 'is-muted': microphoneMuted || microphoneUnavailable || deafened, 'is-speaking': isSpeaking, 'is-deafened': deafened }" :aria-label="state" :title="state">
    <svg v-if="isSpeaking" class="voice-person-state-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 10v4M8 7v10M12 4v16M16 7v10M20 10v4" /></svg>
    <template v-else-if="deafened">
      <span class="voice-person-state-icons" aria-hidden="true">
        <svg class="voice-person-state-icon" viewBox="0 0 24 24"><path d="M12 3a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3ZM5 11v2a7 7 0 0 0 14 0v-2M12 20v2M9 22h6m-11-18 16 16" /></svg>
        <svg class="voice-person-state-icon" viewBox="0 0 24 24"><path d="M3 13v-2a9 9 0 0 1 16.1-5.5M21 12v2m-18 0h4v5H5a2 2 0 0 1-2-2v-3Zm18 0h-4v5h2a2 2 0 0 0 2-2v-3Zm-17-10 16 16" /></svg>
      </span>
    </template>
    <svg v-else class="voice-person-state-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3ZM5 11v2a7 7 0 0 0 14 0v-2M12 20v2M9 22h6" /><path v-if="microphoneMuted || microphoneUnavailable" d="m4 4 16 16" /></svg>
    <span v-if="!compact">{{ state }}</span>
  </span>
</template>
