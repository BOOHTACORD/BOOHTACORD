<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { listAuditEvents, type AuditEvent } from '../../identity/admin_directory_client'
import { requestFailureMessage } from '../../request_feedback'
import AdminAuditFilters from './AdminAuditFilters.vue'
import { presentAuditEvent } from './audit_event_display'
import { appendAuditPage, filterAuditEvents, groupAuditDays, type AuditFilters } from './audit_filter'

const events = ref<AuditEvent[]>([])
const cursor = ref<string | undefined>()
const loading = ref(false)
const error = ref<string | null>(null)
const filters = ref<AuditFilters>({ scope: 'all' })
const filtered = computed(() => filterAuditEvents(events.value, filters.value))
const days = computed(() => groupAuditDays(filtered.value).map((day) => ({ ...day,
  events: day.events.map((event) => ({ ...event, ...presentAuditEvent(event) })),
})))
const hasFilter = computed(() => filters.value.scope !== 'all' || Boolean(filters.value.from || filters.value.to || filters.value.type || filters.value.actor))

async function load(before?: string): Promise<void> {
  if (loading.value) return
  loading.value = true
  error.value = null
  try {
    const page = await listAuditEvents(before)
    events.value = before ? appendAuditPage(events.value, page.events) : page.events
    cursor.value = page.next_cursor
  } catch (cause) { error.value = requestFailureMessage(cause, 'Не удалось загрузить аудит.') }
  finally { loading.value = false }
}
onMounted(() => { void load() })
</script>

<template>
  <section class="admin-audit" aria-labelledby="admin-audit-title">
    <header class="admin-section-heading"><div><h2 id="admin-audit-title">Аудит</h2><p>События управления без содержимого сообщений</p></div>
      <button type="button" :disabled="loading" @click="load()">Обновить</button></header>
    <AdminAuditFilters v-model:filters="filters" :events="events" />
    <p class="admin-audit-results" role="status" aria-live="polite">Показано: {{ filtered.length }} из {{ events.length }} загруженных</p>
    <p class="admin-audit-scope">Фильтр по загруженным записям. Более ранние события — на следующей странице.</p>
    <p v-if="loading && !events.length" class="state" aria-live="polite">Загружаем аудит…</p>
    <p v-else-if="!loading && !events.length && !error" class="state">Записей пока нет.</p>
    <p v-else-if="!filtered.length && hasFilter" class="state">Среди загруженных записей совпадений нет.</p>
    <section v-for="day in days" :key="day.key" class="admin-audit-day" :aria-label="day.label">
      <h3>{{ day.label }}</h3>
      <ol class="audit-event-list">
        <li v-for="event in day.events" :key="event.id">
          <div class="admin-audit-summary"><span><strong>{{ event.actor }}</strong> → {{ event.title }}<template v-if="event.target"> → {{ event.target }}</template></span>
            <time :datetime="event.created_at">{{ new Date(event.created_at).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' }) }}</time></div>
          <details class="admin-audit-details"><summary>Детали события</summary>
            <dl><dt>Тип</dt><dd>{{ event.event_type }}</dd><dt>Время</dt><dd>{{ new Date(event.created_at).toLocaleString('ru-RU') }}</dd>
              <template v-if="event.target"><dt>Объект</dt><dd>{{ event.target }}</dd></template></dl>
          </details>
        </li>
      </ol>
    </section>
    <button v-if="cursor" class="admin-more" type="button" :disabled="loading" @click="load(cursor)">Показать более ранние</button>
    <p v-if="error" class="admin-error" role="alert">{{ error }}</p>
  </section>
</template>
