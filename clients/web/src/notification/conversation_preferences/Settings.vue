<script setup lang="ts">
import { computed,ref,watch } from 'vue'
import { useNotificationStore } from '../notification_store'
import { useTopologyStore } from '../../channel/topology_store'
import { useDirectMessageStore } from '../../direct_message/direct_message_store'
import type { ConversationKind,NotificationMode } from './policy'
import { useServerNotifications } from '../server_preferences/state'
const remote=useServerNotifications()
const notifications=useNotificationStore(),topology=useTopologyStore(),direct=useDirectMessageStore()
const choices=computed(()=>[
  ...(topology.topology?.categories.flatMap(category=>category.channels).filter(channel=>channel.kind==='TEXT') ?? [])
    .map(channel=>({key:`CHANNEL:${channel.id}`,kind:'CHANNEL' as const,id:channel.id,name:`# ${channel.name}`})),
  ...direct.directMessages.map(dm=>({key:`DIRECT_MESSAGE:${dm.id}`,kind:'DIRECT_MESSAGE' as const,id:dm.id,name:`Личные: ${dm.otherParticipantDisplayName}`})),
])
const selected=ref('')
watch(choices,list=>{if(!list.some(item=>item.key===selected.value)) selected.value=list[0]?.key ?? ''},{immediate:true})
const target=computed(()=>choices.value.find(item=>item.key===selected.value))
const preference=computed(()=>target.value ? notifications.conversationPreference(target.value.kind,target.value.id) : null)
const now=ref(Date.now()), busy=ref(false)
async function update(mode:NotificationMode,pausedUntil:number):Promise<void> {
  const current=target.value
  if(!current || busy.value) return
  busy.value=true
  try {await notifications.setConversationPreference(current.kind as ConversationKind,current.id,{mode,pausedUntil})}
  finally {busy.value=false;now.value=Date.now()}
}
async function changeMode(event:Event):Promise<void> {
  const select=event.target as HTMLSelectElement
  await update(select.value as NotificationMode,preference.value?.pausedUntil ?? 0)
  select.value=preference.value?.mode ?? 'all'
}
function pause(event:Event):void {
  const minutes=Number((event.target as HTMLSelectElement).value)
  void update(preference.value?.mode ?? 'all',minutes>0 ? Date.now()+minutes*60000 : 0)
}
</script>
<template>
  <section aria-labelledby="conversation-notifications-title" class="conversation-notification-settings">
    <h3 id="conversation-notifications-title">Настройки бесед</h3>
    <details class="copy-help"><summary>Режимы уведомлений</summary><p>Счётчики непрочитанных сохраняются. В режиме упоминаний проверяется точное сообщение; личный текст в уведомление не попадает.</p></details>
    <p v-if="!choices.length">Сначала откройте доступную беседу.</p>
    <template v-else>
      <label>Беседа<select v-model="selected" :disabled="busy"><option v-for="item in choices" :key="item.key" :value="item.key">{{ item.name }}</option></select></label>
      <label>Уведомлять<select :value="preference?.mode" :disabled="busy" @change="changeMode"><option value="all">Все сообщения</option><option value="mentions">Только упоминания</option><option value="none">Без уведомлений</option></select></label>
      <label>Пауза<select :value="0" :disabled="busy" @change="pause"><option value="0">Без паузы / возобновить</option><option value="15">15 минут</option><option value="60">1 час</option><option value="480">8 часов</option></select></label>
      <p v-if="preference && preference.pausedUntil>now" role="status">Пауза до {{ new Date(preference.pausedUntil).toLocaleString('ru-RU') }}. После неё выбранный режим возобновится автоматически.</p>
    </template>
    <button type="button" class="profile-secondary-button" :disabled="busy" @click="notifications.resetConversationPreferences()">{{ remote.snapshot ? 'Убрать исключения бесед: использовать общие настройки' : 'Сбросить настройки всех бесед: все сообщения, без паузы' }}</button>
  </section>
</template>
<style scoped>
.conversation-notification-settings { display:grid; gap:var(--space-2,8px); }
label { display:grid; gap:var(--space-1,4px); }
select { color:var(--text-primary); background:var(--panel); border:1px solid var(--border); border-radius:var(--radius-md,8px); padding:var(--space-2,8px); }
</style>
