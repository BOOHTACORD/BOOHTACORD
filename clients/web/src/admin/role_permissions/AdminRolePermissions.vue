<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { memberPermissionDefaults, type PermissionKey, type PermissionValues } from '../../authorization/permission_keys'
import { loadRolePolicies, RolePolicyError, saveMemberPolicy, type RoleName, type RolePolicy } from './role_policy_client'
import { changed, copyPermissions, newlyGrantedDeletes } from './role_policy_editor'
import { createConflictReview } from '../../channel/conflict_review/state'
import { AdminResponseError, adminRequestFeedback } from '../admin_request_feedback'
import Comparison from '../../channel/conflict_review/Comparison.vue'

const labels: Record<PermissionKey, string> = {
  'channel.text.create': 'Создавать текстовые каналы', 'channel.text.delete': 'Удалять текстовые каналы',
  'channel.voice.create': 'Создавать голосовые каналы', 'channel.voice.delete': 'Закрывать голосовые каналы',
  'category.create': 'Создавать разделы', 'category.delete': 'Удалять пустые разделы',
}
const permissionRows: Array<{ name: string; description: string; icon: 'text' | 'voice' | 'folder'; create: PermissionKey; remove: PermissionKey }> = [
  { name: 'Текстовые каналы', description: 'Удаление архивирует историю', icon: 'text', create: 'channel.text.create', remove: 'channel.text.delete' },
  { name: 'Голосовые каналы', description: 'Удаление отключает участников', icon: 'voice', create: 'channel.voice.create', remove: 'channel.voice.delete' },
  { name: 'Разделы', description: 'Только пустые разделы', icon: 'folder', create: 'category.create', remove: 'category.delete' },
]
const roles = ref<RolePolicy[]>([]); const selected = ref<RoleName>('MEMBER'); const revision = ref(0)
const baseline = ref<PermissionValues>(memberPermissionDefaults()); const draft = ref<PermissionValues>(memberPermissionDefaults())
const loading = ref(false); const saving = ref(false); const error = ref(''); const status = ref('')
const denied = ref(false)
const current = computed(() => roles.value.find((role) => role.role === selected.value) ?? null)
const orderedRoles = computed(() => [...roles.value].sort((left, right) => left.role === 'ADMINISTRATOR' ? -1 : right.role === 'ADMINISTRATOR' ? 1 : 0))
const dirty = computed(() => selected.value === 'MEMBER' && changed(baseline.value, draft.value))
const displayed = computed(() => selected.value === 'MEMBER' ? draft.value : current.value?.permissions ?? draft.value)
const review=createConflictReview<PermissionValues>()
function summary(value:PermissionValues|null):string {return value ? Object.entries(value).map(([key,on])=>`${labels[key as PermissionKey]}: ${on ? 'да' : 'нет'}`).join('; ') : ''}
function roleErrorMessage(cause: unknown): string {
  if (cause instanceof RolePolicyError && cause.status === 401) return 'Сессия завершена. Войдите снова.'
  if (cause instanceof RolePolicyError && cause.status === 403) return 'Нет доступа к изменению разрешений этой роли.'
  if (cause instanceof RolePolicyError && cause.code === 'REQUEST_FAILED') return adminRequestFeedback(new AdminResponseError(cause.status)).message
  return adminRequestFeedback(cause).message
}

async function load(resetDraft = true): Promise<void> {
  loading.value = true; error.value = ''; status.value = ''
  try {
    const page = await loadRolePolicies(); roles.value = page.roles; revision.value = page.revision; denied.value = false
    const member = page.roles.find((role) => role.role === 'MEMBER')!
    if(!resetDraft&&dirty.value&&!review.before.value&&changed(baseline.value,member.permissions)) review.capture(copyPermissions(baseline.value),copyPermissions(draft.value))
    baseline.value = copyPermissions(member.permissions)
    if(review.before.value) review.refresh(copyPermissions(member.permissions),page.revision)
    if (resetDraft) {draft.value = copyPermissions(member.permissions);review.reset()}
  } catch (cause) {
    if (cause instanceof RolePolicyError && (cause.status === 401 || cause.status === 403)) denied.value = true
    error.value = roleErrorMessage(cause)
  }
  finally { loading.value = false }
}
function choose(role: RoleName): void {
  if (role === selected.value) return
  if (dirty.value && !window.confirm('Отменить несохранённые изменения?')) return
  selected.value = role; draft.value = copyPermissions(baseline.value); error.value = ''; status.value = ''
}
function reset(): void { draft.value = memberPermissionDefaults(); status.value = 'Загружены значения по умолчанию. Нажмите «Сохранить».' }
function cancel(): void { draft.value = copyPermissions(baseline.value);review.reset();error.value = ''; status.value = '' }
async function save(reviewed=false): Promise<void> {
  if(saving.value||loading.value||review.before.value&&!reviewed||reviewed&&!review.ready(revision.value)) return
  const grants = newlyGrantedDeletes(baseline.value, draft.value)
  if (grants.length && !window.confirm('Выдать участникам права удаления? Это позволит удалять объекты гильдии.')) return
  saving.value = true; error.value = ''; status.value = ''
  try { await saveMemberPolicy(revision.value, draft.value, grants.length > 0); await load(true); status.value = 'Разрешения участников сохранены.' }
  catch (cause) {
    if(cause instanceof RolePolicyError&&cause.status===409){review.capture(copyPermissions(baseline.value),copyPermissions(draft.value));await load(false)}
    if (cause instanceof RolePolicyError && (cause.status === 401 || cause.status === 403)) denied.value = true
    error.value = cause instanceof RolePolicyError && cause.status === 409 ? 'Настройки уже изменены другим администратором. Черновик сохранён; обновите данные или отмените изменения.' : roleErrorMessage(cause)
  } finally { saving.value = false }
}
function guard(event: BeforeUnloadEvent): void { if (dirty.value) event.preventDefault() }
onMounted(() => { window.addEventListener('beforeunload', guard); void load() })
onBeforeUnmount(() => window.removeEventListener('beforeunload', guard))
</script>

<template>
  <section class="role-permissions" aria-labelledby="role-permissions-title">
    <header class="admin-section-heading"><div><h2 id="role-permissions-title">Роли и разрешения</h2></div><button type="button" :disabled="loading" @click="load(false)">Обновить</button></header>
    <div class="role-selector" role="tablist" aria-label="Роль"><button v-for="role in orderedRoles" :key="role.role" type="button" role="tab" :aria-selected="selected === role.role" @click="choose(role.role)">{{ role.role === 'MEMBER' ? 'Пользователь' : role.displayName }}</button></div>
    <p v-if="loading && !roles.length" class="state" aria-live="polite">Загружаем разрешения…</p>
    <fieldset v-else class="role-permission-fieldset" :disabled="selected === 'ADMINISTRATOR' || saving"><legend class="gc-sr-only">Разрешения роли</legend>
      <header class="role-permission-table-heading"><h3>Управление каналами</h3><span>6 разрешений</span></header>
      <table class="role-permission-table"><thead><tr><th scope="col">Объект</th><th scope="col">Создавать</th><th scope="col">Удалять</th></tr></thead>
        <tbody><tr v-for="row in permissionRows" :key="row.name"><th scope="row"><span class="role-permission-object"><span class="role-permission-icon" aria-hidden="true"><svg v-if="row.icon === 'text'" viewBox="0 0 24 24"><path d="M4 9h16M3 15h16M10 3 8 21M16 3l-2 18" /></svg><svg v-else-if="row.icon === 'voice'" viewBox="0 0 24 24"><path d="M7 10v4a5 5 0 0 0 10 0v-4M12 19v3M8 22h8M12 2v8" /></svg><svg v-else viewBox="0 0 24 24"><path d="M3 5h7l2 2h9v12H3z" /></svg></span><span class="role-permission-label"><span>{{ row.name }}</span><small>{{ row.description }}</small></span></span></th>
          <td><input v-model="displayed[row.create]" type="checkbox" :aria-label="labels[row.create]" :disabled="selected === 'ADMINISTRATOR'"></td>
          <td><input v-model="displayed[row.remove]" type="checkbox" :aria-label="labels[row.remove]" :disabled="selected === 'ADMINISTRATOR'"></td>
        </tr></tbody>
      </table>
      <p class="role-permission-notice"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" /><path d="M12 11v5m0-8h.01" /></svg><span>Разрешение удаления действует на любые каналы, в том числе созданные другими участниками и администраторами.</span></p>
    </fieldset>
    <p v-if="selected === 'ADMINISTRATOR'" class="role-policy-note">Разрешения администратора обязательны и не изменяются.</p>
    <Comparison v-if="review.before.value" :before="summary(review.before.value)" :current="review.current.value ? summary(review.current.value) : null" :proposed="summary(draft)" :ready="review.ready(revision)" :busy="saving || loading" @refresh="load(false)" @discard="cancel" @apply="save(true)" />
    <div v-else class="role-policy-actions"><span v-if="dirty || saving" class="role-policy-status" role="status" aria-live="polite">{{ saving ? 'Сохраняем…' : 'Есть несохранённые изменения' }}</span><button type="button" :disabled="saving" @click="reset">По умолчанию</button><button type="button" :disabled="saving" @click="cancel">Отменить</button><button type="button" :disabled="!dirty || saving || denied" @click="save()">Сохранить</button></div>
    <p v-if="status" class="admin-status" role="status" aria-live="polite">{{ status }}</p><p v-if="error" class="admin-error" role="alert">{{ error }}</p>
  </section>
</template>
