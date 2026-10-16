<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'
import { changeOwnPassword, deleteAvatar, loadOwnProfile, saveOwnProfile, uploadAvatar, type OwnProfile } from './profile_client'
import AdminConfirmation from '../channel/AdminConfirmation.vue'
import NotificationSettings from '../notification/NotificationSettings.vue'
import UpdateStatus from '../updates/UpdateStatus.vue'
import OwnSessionsPanel from './own_sessions/OwnSessionsPanel.vue'
type ProfileTab = 'profile' | 'security' | 'notifications' | 'about'

const props = defineProps<{ profile: OwnProfile | null; loading: boolean; loadError: string | null; logoutBusy?: boolean; logoutError?: string | null }>()
const emit = defineEmits<{ saved: [profile: OwnProfile]; logout: []; sessionExpired: [] }>()
const displayName = ref(''); const currentPassword = ref(''); const newPassword = ref('')
const busy = ref(false); const busyAction = ref<'name' | 'avatar' | 'password' | null>(null); const error = ref<string | null>(null); const profileStatus = ref<string | null>(null); const passwordStatus = ref<string | null>(null)
const activeTab = ref<ProfileTab>('profile')
const profileTabs: readonly ProfileTab[] = ['profile', 'security', 'notifications', 'about']
const nameChanged = computed(() => displayName.value !== (props.profile?.display_name ?? ''))
const passwordChanged = computed(() => currentPassword.value.length > 0 || newPassword.value.length > 0)
const hasUnsavedChanges = computed(() => nameChanged.value || passwordChanged.value)
const discardConfirmation = ref<{ ask: (message: string) => Promise<boolean> } | null>(null)
const logoutConfirmation = ref<{ ask: (message: string) => Promise<boolean> } | null>(null)
const title = ref<HTMLElement | null>(null)
let focusFrame: number | null = null
onMounted(() => { focusFrame = window.requestAnimationFrame(() => title.value?.focus()) })
onBeforeUnmount(() => { if (focusFrame !== null) window.cancelAnimationFrame(focusFrame) })
watch(() => props.profile, (profile) => { displayName.value = profile?.display_name ?? '' }, { immediate: true })
watch(displayName, () => { if (!busy.value) { error.value = null; profileStatus.value = null } })
watch([currentPassword, newPassword], () => { if (!busy.value) { error.value = null; passwordStatus.value = null } })
function onProfileTabKeydown(event: KeyboardEvent): void {
  const currentIndex = profileTabs.indexOf(activeTab.value)
  let nextIndex: number
  switch (event.key) {
    case 'ArrowRight': nextIndex = (currentIndex + 1) % profileTabs.length; break
    case 'ArrowLeft': nextIndex = (currentIndex - 1 + profileTabs.length) % profileTabs.length; break
    case 'Home': nextIndex = 0; break
    case 'End': nextIndex = profileTabs.length - 1; break
    default: return
  }
  event.preventDefault()
  activeTab.value = profileTabs[nextIndex]
  void nextTick(() => document.getElementById(`profile-tab-${activeTab.value}`)?.focus())
}
function fail(cause: unknown, fallback: string): void { error.value = cause instanceof Error ? cause.message : fallback }
async function saveName(): Promise<void> {
  error.value = null; profileStatus.value = null
  if (!validCodePointLength(displayName.value, 1, 64)) { error.value = 'Имя должно содержать от 1 до 64 символов.'; return }
  busy.value = true; busyAction.value = 'name'; profileStatus.value = 'Сохраняем имя профиля…'
  try { const profile = await saveOwnProfile(displayName.value); emit('saved', profile); profileStatus.value = 'Имя профиля сохранено.' } catch (cause) { profileStatus.value = null; fail(cause, 'Не удалось сохранить профиль.') } finally { busy.value = false; busyAction.value = null }
}
async function selectAvatar(event: Event): Promise<void> {
  const input = event.target as HTMLInputElement; const file = input.files?.[0]; if (!file) return
  error.value = null; profileStatus.value = 'Обновляем аватар…'; busy.value = true; busyAction.value = 'avatar'
  try { await uploadAvatar(file); emit('saved', await loadOwnProfile()); profileStatus.value = 'Аватар обновлён.' } catch (cause) { profileStatus.value = null; fail(cause, 'Не удалось загрузить аватар.') } finally { busy.value = false; busyAction.value = null; input.value = '' }
}
async function removeAvatar(): Promise<void> {
  error.value = null; profileStatus.value = 'Удаляем аватар…'; busy.value = true; busyAction.value = 'avatar'
  try { await deleteAvatar(); emit('saved', await loadOwnProfile()); profileStatus.value = 'Аватар удалён.' } catch (cause) { profileStatus.value = null; fail(cause, 'Не удалось удалить аватар.') } finally { busy.value = false; busyAction.value = null }
}
async function changePassword(): Promise<void> {
  error.value = null; passwordStatus.value = null
  if (!validCodePointLength(currentPassword.value, 12, 128) || !validCodePointLength(newPassword.value, 12, 128)) { error.value = 'Пароль должен содержать от 12 до 128 символов.'; return }
  busy.value = true; busyAction.value = 'password'; passwordStatus.value = 'Обновляем пароль…'
  try { await changeOwnPassword(currentPassword.value, newPassword.value); currentPassword.value = ''; newPassword.value = ''; passwordStatus.value = 'Пароль изменён. Другие сессии завершены.' } catch (cause) { passwordStatus.value = null; fail(cause, 'Не удалось изменить пароль.') } finally { busy.value = false; busyAction.value = null }
}
async function requestLogout(): Promise<void> {
  if (hasUnsavedChanges.value && !await discardConfirmation.value?.ask('Введённое имя или пароль ещё не сохранены. Если уйти, эти данные будут потеряны. Продолжить?')) return
  if (!await logoutConfirmation.value?.ask('Голосовое подключение завершится, а личные данные исчезнут с этого экрана. Выйти из аккаунта?')) return
  emit('logout')
}
defineExpose({ hasUnsavedChanges })
</script>

<template>
  <section class="profile-settings" aria-labelledby="profile-settings-title" data-testid="profile-settings">
    <header><h1 id="profile-settings-title" ref="title" tabindex="-1">Настройки</h1></header>
    <nav class="profile-tabs" role="tablist" aria-label="Настройки аккаунта" @keydown="onProfileTabKeydown">
      <button id="profile-tab-profile" type="button" role="tab" aria-controls="profile-panel-profile" :aria-selected="activeTab === 'profile'" :tabindex="activeTab === 'profile' ? 0 : -1" @click="activeTab = 'profile'">Профиль</button>
      <button id="profile-tab-security" type="button" role="tab" aria-controls="profile-panel-security" :aria-selected="activeTab === 'security'" :tabindex="activeTab === 'security' ? 0 : -1" @click="activeTab = 'security'">Безопасность</button>
      <button id="profile-tab-notifications" type="button" role="tab" aria-controls="profile-panel-notifications" :aria-selected="activeTab === 'notifications'" :tabindex="activeTab === 'notifications' ? 0 : -1" @click="activeTab = 'notifications'">Уведомления</button>
      <button id="profile-tab-about" type="button" role="tab" aria-controls="profile-panel-about" :aria-selected="activeTab === 'about'" :tabindex="activeTab === 'about' ? 0 : -1" @click="activeTab = 'about'">О приложении</button>
    </nav>
    <p v-if="props.loading" class="state" aria-live="polite">Загружаем профиль…</p>
    <p v-else-if="props.loadError" class="state state-error" role="alert">{{ props.loadError }}</p>
    <template v-else-if="props.profile && activeTab === 'profile'">
      <section id="profile-panel-profile" class="profile-panel" role="tabpanel" aria-labelledby="profile-tab-profile" tabindex="0">
      <div class="profile-avatar-row">
        <img v-if="props.profile.avatar_url" class="profile-avatar" :src="props.profile.avatar_url" alt="Аватар профиля">
        <span v-else class="profile-avatar profile-avatar--empty" aria-hidden="true">{{ props.profile.display_name.slice(0, 2).toLocaleUpperCase('ru-RU') }}</span>
        <div class="profile-avatar-copy"><h2>{{ props.profile.display_name }}</h2><p>@{{ props.profile.login }} · {{ props.profile.role === 'ADMINISTRATOR' ? 'Администратор' : 'Участник' }}</p><label class="profile-upload-button">Изменить аватар<input type="file" accept="image/png,image/jpeg" :disabled="busy" @change="selectAvatar"></label></div>
        <button v-if="props.profile.avatar_url" class="profile-secondary-button" type="button" :disabled="busy" @click="removeAvatar">Удалить</button>
      </div>
      <form class="profile-form" :aria-busy="busyAction === 'name'" @submit.prevent="saveName">
        <label>Отображаемое имя<input v-model="displayName" autocomplete="nickname" required :disabled="busy" :aria-describedby="error ? 'profile-error' : undefined"></label>
        <label>Логин<input :value="props.profile.login" readonly aria-readonly="true"></label>
        <div class="profile-savebar"><span role="status" aria-live="polite">{{ profileStatus || (nameChanged ? 'Есть несохранённые изменения' : 'Изменения не внесены') }}</span><button type="submit" :disabled="busy || !nameChanged">{{ busyAction === 'name' ? 'Сохраняем…' : 'Сохранить профиль' }}</button></div>
      </form>
      </section>
    </template>
    <template v-else-if="props.profile && activeTab === 'security'">
      <section id="profile-panel-security" class="profile-panel" role="tabpanel" aria-labelledby="profile-tab-security" tabindex="0">
      <form class="profile-form profile-password-form" :aria-busy="busyAction === 'password'" @submit.prevent="changePassword">
        <h2>Изменить пароль</h2>
        <label>Текущий пароль<input v-model="currentPassword" type="password" autocomplete="current-password" required :disabled="busy" :aria-describedby="error ? 'profile-error' : undefined"></label>
        <label>Новый пароль<input v-model="newPassword" type="password" autocomplete="new-password" required :disabled="busy" :aria-describedby="error ? 'profile-error' : undefined"></label>
        <p role="status" aria-live="polite">{{ passwordStatus || (passwordChanged ? 'Пароль пока не изменён. Нажмите «Обновить пароль», чтобы сохранить его.' : 'Изменение пароля требует явного подтверждения кнопкой «Обновить пароль».') }}</p>
        <button type="submit" :disabled="busy">Обновить пароль</button>
      </form>
      <section class="profile-logout" aria-labelledby="profile-logout-title">
        <h2 id="profile-logout-title">Выход из аккаунта</h2>
        <p>Голосовое подключение завершится, а личные данные исчезнут с этого экрана.</p>
        <button class="profile-secondary-button" type="button" :disabled="busy || props.logoutBusy" @click="requestLogout">{{ props.logoutBusy ? 'Выходим…' : 'Выйти из аккаунта' }}</button>
        <p v-if="props.logoutError" class="profile-error" role="alert">{{ props.logoutError }}</p>
      </section>
      <OwnSessionsPanel :account-id="props.profile.account_id" @session-expired="emit('sessionExpired')" />
      </section>
    </template>
    <template v-else-if="props.profile && activeTab === 'notifications'"><section id="profile-panel-notifications" class="profile-panel" role="tabpanel" aria-labelledby="profile-tab-notifications" tabindex="0"><NotificationSettings /></section></template>
    <template v-else-if="props.profile && activeTab === 'about'"><section id="profile-panel-about" class="profile-panel" role="tabpanel" aria-labelledby="profile-tab-about" tabindex="0"><UpdateStatus /></section></template>
    <p v-if="error" id="profile-error" class="profile-error" role="alert">{{ error }}</p>
    <AdminConfirmation ref="discardConfirmation" id="profile-discard-confirm" title="Несохранённые изменения" confirm-label="Выйти без сохранения" />
    <AdminConfirmation ref="logoutConfirmation" id="profile-logout-confirm" title="Подтвердите выход из аккаунта" confirm-label="Выйти" />
  </section>
</template>
