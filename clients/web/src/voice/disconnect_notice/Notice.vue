<script setup lang="ts">
import type { VoiceDisconnectNotice } from './model'
withDefaults(defineProps<{ notice: VoiceDisconnectNotice; announce?: boolean }>(), { announce: true })
</script>
<template>
  <div class="state" :class="{ 'state-error': notice.reason !== 'VOLUNTARY_LEAVE' }" :role="announce === false ? undefined : 'status'" :aria-live="announce === false ? undefined : 'polite'" aria-atomic="true" data-testid="voice-disconnect-notice">
    <p>{{ notice.message }}</p><p v-if="notice.explanation">{{ notice.explanation }}</p>
  </div>
</template>
