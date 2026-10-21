<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, onDeactivated, onActivated } from 'vue'
import { readTelemetry, writeTelemetry, type TelemetrySettings } from './client'
const value = ref<TelemetrySettings | null>(null), busy = ref(false), error = ref(''), endpoint = ref(''), consent = ref(false)
let generation = 0, controller: AbortController | null = null
const labels: Record<string, string> = { disabled: 'Отправка выключена', unavailable: 'ID установки недоступен', never_connected: 'Нет подтверждения приёма', exporting: 'Центр принимает данные', degraded: 'Ошибка доставки', revoked: 'Регистрация отозвана', stale: 'Нет свежего подтверждения' }
async function update(mode?: 'local_only' | 'central') {
  if (busy.value) return
  const ticket = ++generation; controller = new AbortController(); busy.value = true; error.value = ''
  try {
    const result = mode ? await writeTelemetry({ mode, endpoint: endpoint.value.trim(), confirmed: consent.value }, undefined, controller.signal) : await readTelemetry(undefined, controller.signal)
    if (ticket === generation) { value.value = result; consent.value = false }
  } catch (reason) { if (ticket === generation) error.value = reason instanceof Error ? reason.message : 'Не удалось загрузить телеметрию.' }
  finally { if (ticket === generation) busy.value = false }
}
function stop() { generation++; controller?.abort(); busy.value = false; consent.value = false; value.value = null }
onMounted(() => { void update() }); onActivated(() => { if (!value.value) void update() }); onBeforeUnmount(stop); onDeactivated(stop)
</script>
<template>
  <section class="installation-telemetry" aria-labelledby="installation-telemetry-title" :aria-busy="busy">
    <h2 id="installation-telemetry-title">Диагностика установки</h2>
    <p>По умолчанию диагностика остаётся на вашем сервере. Подключение центра добровольное; чат и голос работают независимо от его доступности.</p>
    <template v-if="value">
      <dl><dt>ID установки</dt><dd>{{ value.installation_id || 'Недоступен' }}</dd><dt>Режим</dt><dd>{{ value.mode === 'central' ? 'Метрики и очищенные traces' : 'Только локально' }}</dd><dt>Регистрация</dt><dd>{{ value.registered ? 'Есть credential установки' : 'Не подключена' }}</dd><dt>Доставка</dt><dd role="status">{{ labels[value.state] }}</dd><dt>Последнее подтверждение приёма</dt><dd>{{ value.last_accepted_at || 'Ещё не получено' }}</dd></dl>
      <p>Подтверждение приёма не гарантирует длительное хранение. Отсутствие данных не означает, что сервер выключен.</p>
      <button v-if="value.mode === 'central'" class="gc-button gc-button--secondary" type="button" :disabled="busy" @click="update('local_only')">Выключить отправку</button>
      <form v-else @submit.prevent="update('central')">
        <label for="telemetry-central-endpoint">HTTPS-адрес центра</label><input id="telemetry-central-endpoint" v-model="endpoint" class="gc-field" type="url" placeholder="https://telemetry.example.org" :disabled="busy" required autocomplete="off">
        <label class="telemetry-consent"><input v-model="consent" type="checkbox" :disabled="busy">Разрешаю отправлять агрегированные метрики и очищенные traces со стабильными псевдонимами пользователей. Содержимое переписки, вложения, звук и экран не отправляются.</label>
        <button class="gc-button" type="submit" :disabled="busy || !consent || !endpoint.trim() || value.state === 'unavailable'">Подключить центр</button>
      </form>
    </template>
    <p v-if="error" role="alert">{{ error }}</p>
    <button class="gc-button gc-button--secondary" type="button" :disabled="busy" @click="update()">{{ busy ? 'Проверяем…' : 'Обновить состояние' }}</button>
  </section>
</template>
<style scoped>
.installation-telemetry { display: grid; gap: 12px; padding: 24px; max-width: 640px; overflow-wrap: anywhere; }
form { display: grid; gap: 12px; } dl { display: grid; gap: 6px; } dd { margin: 0 0 10px; } .telemetry-consent { display: flex; gap: 10px; align-items: flex-start; } .telemetry-consent input { min-width: 24px; min-height: 24px; } button { min-height: 44px; justify-self: start; }
</style>
