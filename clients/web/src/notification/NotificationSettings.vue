<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted } from 'vue'
import { useNotificationStore } from './notification_store'
import ConversationNotificationSettings from './conversation_preferences/Settings.vue'
import { streamStartChime } from '../voice/stream_start_runtime'

const notifications = useNotificationStore()
function changeStreamSound(event:Event):void {const enabled=(event.target as HTMLInputElement).checked;streamStartChime.setEnabled(enabled);if(enabled) streamStartChime.activate()}
onMounted(() => { notifications.refreshStatus(); window.addEventListener('focus', notifications.refreshStatus) })
onBeforeUnmount(() => window.removeEventListener('focus', notifications.refreshStatus))
const status = computed(() => {
  if (!notifications.available) return 'Системные уведомления недоступны в этом браузере.'
  if (notifications.permission === 'denied') return 'Браузер запретил уведомления. Разрешите их в настройках сайта.'
  return notifications.enabled ? 'Уведомления включены.' : 'Уведомления выключены.'
})
</script>

<template>
  <section class="profile-logout" aria-labelledby="profile-notifications-title">
    <h2 id="profile-notifications-title">Уведомления</h2>
    <p>Текст личных сообщений в уведомлениях не показывается.</p>
    <details class="copy-help"><summary>Когда приходят уведомления</summary><p>При скрытой вкладке, пока браузер открыт.</p></details>
    <p aria-live="polite">{{ status }}</p>
    <button v-if="notifications.enabled" class="profile-secondary-button" type="button" @click="notifications.disable()">Отключить уведомления</button>
    <button v-else class="profile-secondary-button" type="button" :disabled="!notifications.available || notifications.permission === 'denied'" @click="notifications.enable()">Включить уведомления</button>
    <p v-if="notifications.error" class="profile-error" role="alert">{{ notifications.error }}</p>
    <ConversationNotificationSettings />
    <label><input type="checkbox" :checked="streamStartChime.enabled.value" @change="changeStreamSound"> Отдельный звук начала демонстрации</label>
  </section>
</template>
