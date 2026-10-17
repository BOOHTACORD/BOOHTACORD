<script setup lang="ts">
import { computed,onActivated,onBeforeUnmount,onDeactivated,onMounted,ref } from 'vue'
import { inspectReadiness,type Readiness } from './client'
import { readinessProbeReason,readinessProbeStatus } from './reason_copy'
import { adminRequestFeedback } from '../admin_request_feedback'
import JourneyPanel from '../../telemetry/journey_intervals/Panel.vue'
const result=ref<Readiness|null>(null),error=ref(''),busy=ref(false),retryable=ref(true),now=ref(Date.now())
let abort:AbortController|null=null,generation=0,timer:ReturnType<typeof setInterval>|null=null
const age=computed(()=>result.value?Math.max(0,Math.floor((now.value-Date.parse(result.value.checked_at))/1000)):null)
const fresh=computed(()=>!error.value&&age.value!==null&&age.value<=15)
const bytes=(value:number|null|undefined)=>value===null||value===undefined?'Неизвестно':`${(value/1024/1024).toFixed(1)} МиБ`
async function refresh():Promise<void> {
  if(busy.value||!retryable.value) return
  abort?.abort();abort=new AbortController();const current=++generation;busy.value=true
  try {const value=await inspectReadiness(abort.signal);if(current===generation){result.value=value;error.value='';retryable.value=true;now.value=Date.now()}}
  catch(cause){if(current===generation){const feedback=adminRequestFeedback(cause);error.value=feedback.message;retryable.value=feedback.retryable}}
  finally{if(current===generation) busy.value=false}
}
function startMonitoring():void {
  now.value=Date.now()
  if(!timer) timer=setInterval(()=>{now.value=Date.now()},1000)
  if(retryable.value&&!busy.value&&(!result.value||Date.now()-Date.parse(result.value.checked_at)>15000||error.value)) void refresh()
}
function stopMonitoring():void {if(timer) clearInterval(timer);timer=null}
onMounted(startMonitoring)
onActivated(startMonitoring)
onDeactivated(stopMonitoring)
onBeforeUnmount(()=>{generation++;abort?.abort();stopMonitoring()})
</script>
<template>
  <section class="admin-readiness" aria-labelledby="readiness-title">
    <h2 id="readiness-title">Готовность сервисов</h2>
    <details class="copy-help"><summary>Что проверяется</summary><p>Публичный health подтверждает только работу API. Здесь проверяются приватные зависимости и запас для следующей загрузки.</p></details>
    <p role="status">{{ busy ? result ? 'Обновляем проверку; показан предыдущий результат' : 'Проверяем готовность сервисов' : fresh ? result?.status === 'ready' ? 'Сервисы готовы' : 'Есть проблемы готовности' : 'Нет свежего подтверждения готовности' }}</p>
    <p v-if="age !== null">Возраст проверки: {{ age }} с. После 15 с результат считается устаревшим.</p>
    <dl v-if="result" class="readiness-dependencies"><div v-for="(probe,key) in {database:result.database,sfu:result.sfu,storage:result.storage}" :key="key"><dt>{{ key === 'database' ? 'PostgreSQL' : key === 'sfu' ? 'LiveKit' : 'Хранилище' }}</dt><dd :class="`readiness-probe readiness-probe--${fresh ? probe.status : 'stale'}`">{{ readinessProbeStatus(probe.status, !fresh) }}<span v-if="readinessProbeReason(probe.reason)"> · {{ readinessProbeReason(probe.reason) }}</span></dd></div></dl>
    <details v-if="result" class="settings-diagnostics"><summary>Запас и технические показатели · {{ bytes(result.storage.headroom_bytes) }} после резервов</summary><dl class="readiness-capacity"><div><dt>Свободно</dt><dd>{{ bytes(result.storage.available_bytes) }}</dd></div><div><dt>Всего</dt><dd>{{ bytes(result.storage.total_bytes) }}</dd></div><div><dt>Зарезервировано загрузками</dt><dd>{{ bytes(result.storage.reserved_bytes) }}</dd></div><div><dt>Защищённый запас</dt><dd>{{ bytes(result.storage.protected_bytes) }}</dd></div><div><dt>Доступно после резервов</dt><dd>{{ bytes(result.storage.headroom_bytes) }}</dd></div><div><dt>Ожидают отзыва в SFU</dt><dd>{{ result.database.pending_revocations ?? 'Неизвестно' }}</dd></div></dl></details>
    <button type="button" :disabled="busy||!retryable" @click="refresh">{{ busy ? 'Проверяем…' : retryable ? 'Обновить проверку' : 'Обновление недоступно' }}</button>
    <p v-if="error" role="alert">{{ error }}</p>
    <details class="settings-diagnostics"><summary>Локальные измерения браузера</summary><JourneyPanel /></details>
  </section>
</template>
