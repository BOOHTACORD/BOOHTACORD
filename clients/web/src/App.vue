<script setup lang="ts">
import { onMounted, onUnmounted, ref, shallowRef, watch } from 'vue'
import { ActionScope } from './telemetry/action_scope/scope'
import { guildProfile } from './guild/profile/state'

import AuthenticationLanding from './identity/AuthenticationLanding.vue'
import { clearAuthenticatedState } from './identity/clear_authenticated_state'
import { loadCurrentSession, type CurrentSession } from './identity/current_session'
import PasswordResetCompletion from './identity/PasswordResetCompletion.vue'
import { completePasswordReset, PasswordResetInvalidError } from './identity/password_reset_client'
import { consumePasswordResetFragment } from './identity/password_reset_fragment'
import MaintenanceStatus from './maintenance/MaintenanceStatus.vue'
import { useMaintenanceOwner } from './maintenance/context'
import UpdateBanner from './updates/UpdateBanner.vue'
import RequiredUpdateGate from './updates/RequiredUpdateGate.vue'
import { useUpdateStore } from './updates/update_store'
import WorkspaceApp from './workspace/WorkspaceApp.vue'

type AppState = 'loading' | 'guest' | 'authenticated' | 'error'

const state = ref<AppState>('loading')
const error = ref<string | null>(null)
const session = ref<CurrentSession | null>(null)
const readiness=shallowRef<ActionScope>()
const maintenance = useMaintenanceOwner(() => state.value === 'authenticated')
const maintenanceActive = maintenance.active
const maintenanceKnown = maintenance.known
const resetRoute = ref(false)
const focusLoginOnReturn = ref(false)
let resetToken: string | null = null
if (typeof window !== 'undefined') {
  const reset = consumePasswordResetFragment(window.location, window.history)
  resetRoute.value = reset.resetRoute
  resetToken = reset.token
}
let sessionRevision = 0
const updates = useUpdateStore()
watch(guildProfile.name, name => { if (typeof document !== 'undefined') document.title = name }, { immediate: true })

async function refreshSession(flow:'startup'|'session.restore'|'auth.login'='session.restore'): Promise<void> {
  const revision = ++sessionRevision
  readiness.value?.finish('superseded','generation_changed');readiness.value=undefined
  if (session.value) { clearAuthenticatedState(); session.value = null }
  state.value = 'loading'
  error.value = null
  try {
    const current = await loadCurrentSession()
    if (revision !== sessionRevision) return
    session.value = current
    if(current){
      // Preauth work stays local; this observes the authenticated UI readiness.
      readiness.value=new ActionScope(flow);readiness.value.step('restore')
      state.value='authenticated'
      return
    }
    state.value = session.value ? 'authenticated' : 'guest'
  } catch (cause) {
    if (revision !== sessionRevision) return
    session.value = null
    error.value = cause instanceof Error ? cause.message : 'Не удалось проверить сессию.'
    state.value = 'error'
  }
}

function finishLogout(): void {
  readiness.value?.finish('cancelled','disposed');readiness.value=undefined
  sessionRevision++
  session.value = null
  error.value = null
  state.value = 'guest'
}

async function finishPasswordReset(password: string): Promise<void> {
  const token = resetToken
  if (!token) throw new PasswordResetInvalidError()
  await completePasswordReset(token, password)
  resetToken = null
}

function returnToLogin(): void {
  resetToken = null
  resetRoute.value = false
  focusLoginOnReturn.value = true
  sessionRevision++
  session.value = null
  clearAuthenticatedState()
  error.value = null
  state.value = 'guest'
  window.history.replaceState(window.history.state, '', '/')
}

onMounted(() => {
  void guildProfile.refresh()
  if (!resetRoute.value) void refreshSession('startup')
  updates.start()
})

onUnmounted(() => {
  readiness.value?.finish('cancelled','disposed')
  updates.dispose()
})
</script>

<template>
  <MaintenanceStatus :active="maintenanceActive" :known="maintenanceKnown" />
  <UpdateBanner v-show="!updates.required" />
  <PasswordResetCompletion v-if="resetRoute" :valid-link="Boolean(resetToken)" :complete="finishPasswordReset" @invalid-link="resetToken = null" @return-to-login="returnToLogin" />
  <main v-else-if="state === 'loading'" class="session-state" aria-live="polite">Проверяем безопасную сессию…</main>
  <main v-else-if="state === 'error'" class="session-state" role="alert">
    <p>{{ error }}</p>
    <button type="button" @click="refreshSession()">Повторить</button>
  </main>
  <AuthenticationLanding v-else-if="state === 'guest'" :focus-login-on-mount="focusLoginOnReturn" @authenticated="refreshSession('auth.login')" />
  <WorkspaceApp v-else-if="session" :key="session.accountId" :role="session.role" :account-id="session.accountId" :readiness="readiness" @session-expired="refreshSession()" @logged-out="finishLogout" />
  <RequiredUpdateGate v-if="updates.required" />
</template>
