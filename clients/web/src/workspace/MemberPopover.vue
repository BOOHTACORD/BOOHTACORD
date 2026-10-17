<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { kickVoiceParticipant } from '../identity/admin_directory_client'
import { loadMember, type GuildMember } from '../identity/profile_client'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { avatarInitials } from '../design/avatar_initials'
import { useMemberPopoverPosition } from './use_member_popover_position'
import { focusBoundaryTarget } from './workspace_drawer_focus'
import { focusMemberPopover } from './member_popover_focus'

const props = defineProps<{ memberID: string; self: boolean; viewerRole: 'MEMBER' | 'ADMINISTRATOR'; sameVoice: boolean; volume: number; anchor: HTMLElement | null; voiceStatus?: string; modal: boolean }>()
const emit = defineEmits<{ close: [restoreFocus?: boolean]; openDM: [userID: string]; setVolume: [volume: number] }>()
const member = ref<GuildMember | null>(null); const loading = ref(true); const error = ref<string | null>(null); const status = ref<string | null>(null)
const panel = ref<HTMLElement | null>(null)
const content = ref<HTMLElement | null>(null)
const placement = useMemberPopoverPosition(panel, content, () => props.anchor)
let alive = true
async function load(): Promise<void> {
  const ownedFocus = Boolean(panel.value?.contains(document.activeElement))
  loading.value = true; error.value = null
  try { const loaded = await loadMember(props.memberID); if (alive) member.value = loaded }
  catch (cause) { if (alive) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить профиль участника.' }
  finally {
    if (alive) {
      loading.value = false
      await nextTick()
      const lostOwnedControl = ownedFocus && document.activeElement === document.body
      if (alive && ((!props.modal && panel.value?.contains(document.activeElement)) || lostOwnedControl)) focusMemberPopover(panel.value, props.modal)
    }
  }
}
function escape(event: KeyboardEvent): void {
  if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); emit('close'); return }
  if (event.key !== 'Tab' || !props.modal || !panel.value) return
  const items = Array.from(panel.value.querySelectorAll<HTMLElement>('button, input, [href], [tabindex]:not([tabindex="-1"])')).filter(node => !node.matches(':disabled') && node.getClientRects().length > 0)
  const target = focusBoundaryTarget(items, document.activeElement, event.shiftKey)
  if (target) { event.preventDefault(); event.stopPropagation(); target.focus() }
}
function outsidePointer(event: PointerEvent): void {
  if (panel.value && !event.composedPath().includes(panel.value)) emit('close', props.modal)
}
async function kick(): Promise<void> {
  if (!window.confirm('Отключить участника от голосового канала?')) return
  try { const result = await kickVoiceParticipant(props.memberID); status.value = result.revoked_leases ? 'Подключение отозвано.' : 'Активное голосовое подключение не найдено.' }
  catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось отключить участника.' }
}
onMounted(() => {
  document.addEventListener('keydown', escape)
  document.addEventListener('pointerdown', outsidePointer, true)
  void nextTick(() => { if (alive) focusMemberPopover(panel.value, props.modal) })
  void load()
})
onBeforeUnmount(() => {
  alive = false
  document.removeEventListener('keydown', escape)
  document.removeEventListener('pointerdown', outsidePointer, true)
})
</script>

<template>
  <section ref="panel" class="member-popover" role="dialog" :aria-modal="props.modal ? 'true' : 'false'" aria-label="Профиль участника" data-testid="member-popover" tabindex="-1" :style="placement">
    <div ref="content" class="member-popover-content">
    <header><span>Профиль участника</span><button type="button" aria-label="Закрыть профиль" @click="emit('close')">×</button></header>
    <p v-if="loading" class="state" aria-live="polite">Загружаем профиль…</p><p v-else-if="error" class="state state-error" role="alert">{{ error }} <button type="button" @click="load">Повторить</button></p>
    <template v-else-if="member">
      <div class="member-popover-identity" :data-presence="member.presence"><span class="member-popover-avatar-wrap"><img v-if="member.avatar_url" :src="member.avatar_url" alt="" class="member-popover-avatar"><span v-else class="member-popover-avatar member-popover-avatar--empty" :style="{ backgroundColor: avatarBackground(props.memberID), color: avatarForeground(props.memberID) }">{{ avatarInitials(member.display_name) }}</span><span class="member-popover-avatar-presence" aria-hidden="true"></span></span><div><h2 :title="member.display_name">{{ member.display_name }}</h2><p :title="`@${member.login}`">@{{ member.login }}</p><small>{{ member.role === 'ADMINISTRATOR' ? 'Администратор' : 'Пользователь' }}</small><small class="member-popover-presence">{{ member.presence === 'online' ? 'В сети' : member.presence === 'offline' ? 'Не в сети' : 'Статус неизвестен' }}</small></div></div>
      <p v-if="props.voiceStatus" class="member-popover-voice-state">{{ props.voiceStatus }}</p>
      <div class="member-popover-actions"><button v-if="!props.self" type="button" @click="emit('openDM', member.user_id)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M16 8v6a2 2 0 0 0 4 0v-2a8 8 0 1 0-3 6"/></svg>Написать сообщение</button><button v-if="props.viewerRole === 'ADMINISTRATOR' && props.sameVoice && !props.self" type="button" @click="kick">Отключить от голоса</button></div>
      <label v-if="props.sameVoice && !props.self" class="member-volume">Громкость участника <output>{{ props.volume }}%</output><input :aria-label="`Громкость участника ${member.display_name}`" :aria-valuetext="`${props.volume} процентов`" type="range" min="0" max="200" step="1" :value="props.volume" @input="emit('setVolume', Number(($event.target as HTMLInputElement).value))"></label>
      <p v-if="status" class="member-popover-status" aria-live="polite">{{ status }}</p>
    </template>
    </div>
  </section>
</template>
