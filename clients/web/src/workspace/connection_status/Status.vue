<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount, ref } from 'vue'
import type { RealtimeState } from '../../realtime/realtime_store'
import type { VoiceConnectionState } from '../../voice/connection_store'
import { connectionStatus } from './model'
const props = defineProps<{ chat: RealtimeState; voice: VoiceConnectionState;
  rosterAvailable: boolean; lastUpdatedAt: number | null; rosterRetained?: boolean }>()
const emit = defineEmits<{ retryChat: []; retryRoster: [] }>()
const now = ref(Date.now())
let timer: ReturnType<typeof setInterval> | undefined
onMounted(() => { timer = setInterval(() => { now.value = Date.now() }, 1000) })
onBeforeUnmount(() => clearInterval(timer))
const status = computed(() => connectionStatus(props.chat, props.voice, props.rosterAvailable, props.lastUpdatedAt, now.value, props.rosterRetained))
const visible = computed(() => props.chat !== 'CONNECTED' || !props.rosterAvailable || ['RECONNECTING', 'ERROR'].includes(props.voice))
const chatTone = computed(() => props.chat === 'CONNECTED' ? 'connected' : 'reconnecting')
const voiceTone = computed(() => props.voice === 'CONNECTED' || props.voice === 'LISTENER' ? 'voice'
  : props.voice === 'JOINING' || props.voice === 'RECONNECTING' ? 'reconnecting'
    : props.voice === 'ERROR' ? 'unavailable' : 'inactive')
const rosterTone = computed(() => props.rosterAvailable ? 'connected' : props.rosterRetained ? 'reconnecting' : 'unavailable')
</script>
<template>
  <section v-if="visible" class="connection-status" aria-label="Состояние подключений" data-testid="connection-status">
    <div class="connection-status__item">
      <span class="connection-status__indicator" :class="`connection-status__indicator--${chatTone}`" aria-hidden="true"></span>
      <p class="connection-status__label" role="status">{{ status.chat }}</p>
      <button v-if="chat !== 'CONNECTED'" class="connection-status__action" type="button" @click="emit('retryChat')">
        <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M16.8 7.5A7 7 0 1 0 17 10M16.8 3.5v4h-4" /></svg>
        <span>Повторить связь чата</span>
      </button>
    </div>
    <div class="connection-status__item">
      <span class="connection-status__indicator" :class="`connection-status__indicator--${voiceTone}`" aria-hidden="true"></span>
      <p class="connection-status__label" role="status">{{ status.voice }}</p>
    </div>
    <div class="connection-status__item">
      <span class="connection-status__indicator" :class="`connection-status__indicator--${rosterTone}`" aria-hidden="true"></span>
      <p class="connection-status__label">{{ status.roster }}</p>
      <button v-if="!rosterAvailable" class="connection-status__action" type="button" @click="emit('retryRoster')">
        <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M16.8 7.5A7 7 0 1 0 17 10M16.8 3.5v4h-4" /></svg>
        <span>Обновить состав</span>
      </button>
    </div>
  </section>
</template>
<style scoped>
.connection-status {
  display: grid;
  gap: 12px;
  box-sizing: border-box;
  width: 100%;
  margin: 8px 0;
  padding: 12px;
  border: 1px solid var(--gc-border-subtle, #2a2f3a);
  border-radius: var(--gc-radius-lg, 12px);
  color: var(--gc-text-primary, #f4f5fa);
  background: var(--gc-surface, #1a1d26);
  font-size: var(--gc-text-small, 0.8125rem);
}
.connection-status__item {
  display: grid;
  grid-template-columns: 8px minmax(0, 1fr);
  align-items: start;
  column-gap: 8px;
  row-gap: 6px;
  min-width: 0;
}
.connection-status__indicator {
  width: 8px;
  height: 8px;
  margin-top: 0.38em;
  border-radius: 50%;
  background: var(--gc-text-muted, #a0a9be);
  box-shadow: 0 0 0 3px color-mix(in srgb, currentColor 10%, transparent);
}
.connection-status__indicator--connected { color: var(--gc-success, #22c55e); background: currentColor; }
.connection-status__indicator--voice { color: var(--gc-voice, #06b6d4); background: currentColor; }
.connection-status__indicator--reconnecting { color: var(--gc-warning, #f59e0b); background: currentColor; }
.connection-status__indicator--unavailable { color: var(--gc-danger, #ef4444); background: currentColor; }
.connection-status__indicator--inactive { color: var(--gc-text-muted, #a0a9be); background: currentColor; }
.connection-status__label { min-width: 0; margin: 0; color: var(--gc-text-secondary, #b6bdce); line-height: 1.35; overflow-wrap: anywhere; }
.connection-status__action {
  display: inline-flex;
  grid-column: 2;
  align-items: center;
  justify-self: start;
  gap: 7px;
  min-height: 32px;
  max-width: 100%;
  border: 1px solid var(--gc-border-subtle, #2a2f3a);
  border-radius: var(--gc-radius-sm, 6px);
  padding: 4px 9px;
  color: var(--gc-text-primary, #f4f5fa);
  background: var(--gc-surface-raised, #222631);
  font: inherit;
  line-height: 1.25;
  text-align: left;
  cursor: pointer;
  transition: border-color 120ms ease, background-color 120ms ease;
}
.connection-status__action:hover { border-color: var(--gc-border-control, #707b91); background: var(--gc-surface-hover, #272c39); }
.connection-status__action:active { background: var(--gc-surface-selected, #2b3040); }
.connection-status__action:focus-visible { outline: 2px solid var(--gc-focus, #b4a4ff); outline-offset: 2px; }
.connection-status__action svg { width: 15px; height: 15px; flex: 0 0 15px; fill: none; stroke: currentColor; stroke-linecap: round; stroke-linejoin: round; stroke-width: 1.6; }
@media (prefers-reduced-motion: reduce) {
  .connection-status__action { transition: none; }
}
</style>
