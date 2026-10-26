<script setup lang="ts">
import { useServerNotifications } from './state'
import type { Mode } from './client'
const remote = useServerNotifications()
const modes = [{ value: 'all', label: 'Все сообщения' }, { value: 'mentions', label: 'Только упоминания' }, { value: 'none', label: 'Без уведомлений' }]
function mode(kind: 'dm' | 'text', event: Event) { const value = (event.target as HTMLSelectElement).value as Mode; void remote.save(s => { s[kind].mode = value }) }
function pause(kind: 'dm' | 'text', event: Event) { const minutes = Number((event.target as HTMLSelectElement).value); void remote.save(s => { s[kind].paused_until = minutes > 0 ? new Date(Date.now() + minutes * 60000).toISOString() : null }) }
</script>
<template>
  <section v-if="remote.snapshot" class="remote-notifications" aria-label="Фоновые уведомления">
    <p>Доставка зависит от настроек аккаунта, оператора сервера и разрешения устройства. Содержимое сообщений остаётся в приложении.</p>
    <p v-if="!remote.snapshot.capability.available" role="status">Оператор отключил доставку уведомлений.</p>
    <label class="check-row"><input type="checkbox" :checked="remote.snapshot.settings.enabled" :disabled="remote.busy" @change="remote.save(s => { s.enabled = ($event.target as HTMLInputElement).checked })"> Разрешить фоновые уведомления для аккаунта</label>
    <div v-for="kind in (['dm', 'text'] as const)" :key="kind">
      <label>{{ kind === 'dm' ? 'Личные сообщения' : 'Текстовые каналы' }}<select :value="remote.snapshot.settings[kind].mode" :disabled="remote.busy" @change="mode(kind, $event)"><option v-for="m in modes" :key="m.value" :value="m.value">{{ m.label }}</option></select></label>
      <label>Пауза<select :value="0" :disabled="remote.busy" @change="pause(kind, $event)"><option :value="0">Возобновить / без паузы</option><option :value="15">15 минут</option><option :value="60">1 час</option><option :value="480">8 часов</option></select></label>
      <p v-if="remote.snapshot.settings[kind].paused_until">Пауза до {{ new Date(remote.snapshot.settings[kind].paused_until!).toLocaleString('ru-RU') }}</p>
    </div>
    <p role="status">Устройство: {{ remote.status }}. Разрешение браузера само по себе не подтверждает регистрацию.</p>
    <button class="profile-secondary-button" type="button" :disabled="remote.busy || !remote.capability?.web_push_available" @click="remote.enableDevice()">Включить на этом устройстве</button>
    <ul aria-label="Устройства уведомлений"><li v-for="device in remote.devices" :key="device.id">{{ device.transport === 'web_push' ? 'Браузер' : 'Мобильное устройство' }} · {{ device.state }} · до {{ new Date(device.expires_at).toLocaleDateString('ru-RU') }} <button type="button" :disabled="remote.busy || device.state === 'revoked'" @click="remote.revoke(device)">Отозвать</button></li></ul>
    <details v-if="remote.preview?.source_present && !remote.snapshot.settings.imported"><summary>Перенести явные локальные настройки</summary>
      <p>Найдено явных правил: {{ remote.preview.overrides.length }}. {{ remote.preview.local_disabled ? 'Локальные уведомления были выключены.' : '' }} Импорт оставляет фоновую доставку выключенной. Включение аккаунта и устройства выполняется отдельно.</p>
      <p v-for="message in remote.preview.errors" :key="message">{{ message }}</p>
      <button class="profile-secondary-button" type="button" :disabled="remote.busy || !!remote.preview.errors.length" @click="remote.importPreview()">Подтвердить перенос этих правил</button>
    </details>
    <p v-if="remote.error" class="profile-error" role="alert">{{ remote.error }}</p>
  </section>
</template>
<style scoped>.remote-notifications { display:grid; gap:8px } label { display:grid; gap:4px } .check-row { display:flex;align-items:center;gap:8px } select { color:var(--text-primary);background:var(--panel);border:1px solid var(--border);padding:8px }</style>
