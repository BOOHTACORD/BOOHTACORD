<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'
import type { PermissionValues } from '../../authorization/permission_keys'
import { usePermissionStore } from '../../authorization/permission_store'
import { validCodePointLength } from '../../validation/unicode_limits/unicode_limits'
import type { ChannelTopology, TopologyCategory, TopologyChannel, ChannelKind } from '../topology_client'
import type { VoiceRoomRoster } from '../../voice/voice_roster_client'
import type { VoiceNavigationPresence } from '../voice_navigation_presence'
import ChannelNavigation from '../ChannelNavigation.vue'
import AdminConfirmation from '../AdminConfirmation.vue'
import { confirmedTargetIsCurrent } from './confirmed_target'
import { archiveText, closeVoice, createMemberCategory, createMemberChannel, deleteCategory, TopologyMutationError } from './member_topology_client'
import { requestFailureMessage } from '../../request_feedback'

const props = defineProps<{ accountId: string; activeVoiceChannelId?: string; selectedChannelId?: string; topology: ChannelTopology; permissions: PermissionValues; voicePresence: VoiceNavigationPresence | null; voiceRosters?: VoiceRoomRoster[] | null }>()
const emit = defineEmits<{ select: [channel: TopologyChannel]; changed: [] }>()
const permissionStore = usePermissionStore()
const open = ref(false); const name = ref(''); const kind = ref<'CATEGORY' | ChannelKind>('TEXT'); const categoryId = ref('')
const busy = ref(false); const error = ref(''); const status = ref(''); const nameInput = ref<HTMLInputElement | null>(null)
const dialogForm = ref<HTMLFormElement | null>(null); const opener = ref<HTMLElement | null>(null)
const confirmation = ref<{ ask: (message: string) => Promise<boolean>; cancel: () => void } | null>(null); const confirmationLabel = ref('Подтвердить')
let requestId = ''; const retryKeys = new Map<string, string>()
function id(): string { return crypto.randomUUID() }
function permittedKinds(): Array<'CATEGORY' | ChannelKind> {
  return [props.permissions['category.create'] && 'CATEGORY', props.permissions['channel.text.create'] && 'TEXT', props.permissions['channel.voice.create'] && 'VOICE'].filter(Boolean) as Array<'CATEGORY' | ChannelKind>
}
function begin(category?: TopologyCategory): void {
  opener.value = document.activeElement instanceof HTMLElement ? document.activeElement : null
  const available = permittedKinds(); kind.value = category ? (available.includes('TEXT') ? 'TEXT' : 'VOICE') : available[0] ?? 'CATEGORY'
  categoryId.value = category?.id ?? props.topology.categories[0]?.id ?? ''; name.value = ''; error.value = ''; status.value = ''; requestId = id(); open.value = true
  void nextTick(() => nameInput.value?.focus())
}
function changedIntent(): void { requestId = id(); error.value = ''; status.value = '' }
function chooseKind(value: 'CATEGORY' | ChannelKind): void { kind.value = value; changedIntent() }
function categoryLabel(value: string): string { const name = value.toLocaleLowerCase('ru'); return name.charAt(0).toLocaleUpperCase('ru') + name.slice(1) }
function close(force = false): void { if (busy.value && !force) return; open.value = false; void nextTick(() => opener.value?.focus()) }
watch(() => props.accountId, (accountId, previousAccountId) => {
  if (accountId === previousAccountId) return
  const hadCreateDialog = open.value
  const hadConfirmation = confirmation.value?.cancel() ?? false
  if (hadCreateDialog) close(true)
  if (hadCreateDialog || hadConfirmation) {
    status.value = ''
    error.value = 'Учетная запись изменилась. Диалог закрыт.'
  }
})
function containTab(event: KeyboardEvent): void {
  if (event.key !== 'Tab') return
  const items = [...(dialogForm.value?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), select:not(:disabled)') ?? [])].filter((item) => item.offsetParent !== null)
  if (!items.length) { event.preventDefault(); dialogForm.value?.focus(); return }
  const first = items[0]; const last = items.at(-1)
  if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus() }
  else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus() }
}
async function submit(): Promise<void> {
  if (busy.value) return
  if (!name.value.trim() || !validCodePointLength(name.value, 1, 80)) { error.value = 'Введите имя до 80 символов.'; return }
  if (kind.value !== 'CATEGORY' && !categoryId.value) { error.value = 'Сначала создайте раздел.'; return }
  busy.value = true; error.value = ''
  await nextTick(() => dialogForm.value?.focus())
  try {
    if (kind.value === 'CATEGORY') await createMemberCategory(name.value, requestId)
    else await createMemberChannel(categoryId.value, name.value, kind.value, requestId)
    status.value = 'Изменение принято. Обновляем каналы.'; close(true); emit('changed')
  } catch (cause) { await failed(cause) } finally {
    busy.value = false
    if (open.value) await nextTick(() => nameInput.value?.focus())
  }
}
async function failed(cause: unknown): Promise<void> {
  error.value = requestFailureMessage(cause, 'Не удалось изменить каналы.')
  if (cause instanceof TopologyMutationError && cause.status === 403) await permissionStore.refresh()
  if (cause instanceof TopologyMutationError && cause.status === 409) emit('changed')
}
async function remove(target: TopologyCategory | TopologyChannel): Promise<void> {
  if (busy.value) return
  const channel = 'kind' in target; const action = channel && target.kind === 'VOICE' ? 'Закрыть' : channel ? 'Архивировать' : 'Удалить'
  const confirmedAccountId = props.accountId
  const confirmedRevision = props.topology.revision
  const confirmedTarget = channel ? { ...target } : { ...target, channels: [...target.channels] }
  confirmationLabel.value = action
  const outcome = !channel ? 'Пустой раздел будет удалён.' : target.kind === 'TEXT' ? 'Канал скроется из списка, а история сообщений сохранится.' : 'Участники будут отключены от голосового канала.'
  const stopWatchingTarget = watch(() => props.topology, () => {
    if (!confirmedTargetIsCurrent(props.topology, confirmedTarget, confirmedRevision)) confirmation.value?.cancel()
  }, { deep: true })
  let confirmed = false
  try {
    confirmed = !!(await confirmation.value?.ask(`${action} «${confirmedTarget.name}»? ${outcome} Это действие нельзя отменить.`))
  } finally { stopWatchingTarget() }
  if (props.accountId !== confirmedAccountId) return
  if (!confirmedTargetIsCurrent(props.topology, confirmedTarget, confirmedRevision)) {
    error.value = 'Структура изменилась. Действие не выполнено; обновите список и подтвердите его ещё раз.'
    emit('changed')
    return
  }
  if (!confirmed) return
  const signature = `${channel ? target.kind : 'CATEGORY'}:${target.id}:${confirmedRevision}`; const commandId = retryKeys.get(signature) ?? id(); retryKeys.set(signature, commandId); busy.value = true; error.value = ''
  try {
    if (!channel) await deleteCategory(confirmedTarget.id, confirmedRevision, commandId)
    else if (target.kind === 'TEXT') await archiveText(confirmedTarget.id, confirmedRevision, commandId)
    else await closeVoice(confirmedTarget.id, confirmedRevision, commandId)
    retryKeys.delete(signature); status.value = channel && target.kind === 'VOICE' ? 'Закрытие голосового канала принято.' : 'Изменение выполнено.'; emit('changed')
  } catch (cause) { await failed(cause) } finally { busy.value = false }
}
</script>

<template>
  <p v-if="status" class="topology-action-status" aria-live="polite">{{ status }}</p><p v-if="error && !open" class="topology-action-error" role="alert">{{ error }}</p>
  <ChannelNavigation :account-id="accountId" :active-voice-channel-id="activeVoiceChannelId" :selected-channel-id="selectedChannelId" :topology="topology" :permissions="permissions" :voice-presence="voicePresence" :voice-rosters="voiceRosters" @select="emit('select', $event)" @create-global="begin()" @create-in-category="begin" @delete-category="remove" @delete-channel="remove" @changed="emit('changed')" />
  <AdminConfirmation ref="confirmation" id="member-topology-confirm" title="Подтвердите действие" :confirm-label="confirmationLabel" />
  <Teleport to="body"><div v-if="open" class="topology-dialog-backdrop" @click.self="close()"><form ref="dialogForm" tabindex="-1" :aria-busy="busy" class="topology-dialog" :class="{ 'topology-dialog--category': kind === 'CATEGORY' }" role="dialog" aria-modal="true" aria-labelledby="topology-create-title" @submit.prevent="submit" @keydown.esc.stop.prevent="close()" @keydown.stop="containTab">
    <header class="topology-dialog-header"><h2 id="topology-create-title">{{ kind === 'CATEGORY' ? 'Создать раздел' : 'Создать канал' }}</h2><button type="button" aria-label="Закрыть" :disabled="busy" @click="close()"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg></button></header>
    <p class="topology-dialog-description">{{ kind === 'CATEGORY' ? 'Объедините связанные каналы в одном месте.' : 'Новое место для общения в вашей гильдии.' }}</p>
    <div class="topology-dialog-fields">
      <div v-if="kind !== 'CATEGORY'" class="topology-kind-field"><span>Тип канала</span><div class="topology-kind-selector" role="group" aria-label="Тип канала"><button v-for="option in permittedKinds().filter((candidate) => candidate !== 'CATEGORY')" :key="option" type="button" :aria-pressed="kind === option" :disabled="busy" @click="chooseKind(option)"><svg v-if="option === 'TEXT'" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 9h14M4 15h14M11 3 7 21M17 3l-4 18"/></svg><svg v-else viewBox="0 0 24 24" aria-hidden="true"><path d="m11 5-6 4H2v6h3l6 4V5ZM15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14"/></svg>{{ option === 'TEXT' ? 'Текстовый' : 'Голосовой' }}</button></div></div>
      <label class="topology-name-field">{{ kind === 'CATEGORY' ? 'Название раздела' : 'Название канала' }}<input ref="nameInput" v-model="name" :disabled="busy" maxlength="80" required :aria-invalid="error ? 'true' : undefined" :aria-describedby="error ? 'topology-dialog-error' : undefined" @input="changedIntent"></label>
      <label v-if="kind !== 'CATEGORY'" class="topology-category-field">Раздел<select v-model="categoryId" :disabled="busy" @change="changedIntent"><option v-for="category in topology.categories" :key="category.id" :value="category.id">{{ categoryLabel(category.name) }}</option></select></label>
      <p v-if="kind !== 'CATEGORY'" class="topology-dialog-note"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M22 21v-2a4 4 0 0 0-3-3.87"/><circle cx="9" cy="7" r="4"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>Канал будет доступен всем участникам.</p>
      <p v-if="kind !== 'CATEGORY' && !topology.categories.length" class="topology-action-error">Сначала создайте раздел.</p><p v-if="error" id="topology-dialog-error" class="topology-action-error" role="alert">{{ error }}</p>
    </div>
    <div class="topology-dialog-actions"><button type="button" :disabled="busy" @click="close()">Отмена</button><button type="submit" :disabled="busy || (kind !== 'CATEGORY' && !categoryId)">{{ busy ? 'Создаём…' : kind === 'CATEGORY' ? 'Создать раздел' : 'Создать канал' }}</button></div>
  </form></div></Teleport>
</template>
