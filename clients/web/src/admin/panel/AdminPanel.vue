<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import type { TopologyCategory } from '../../channel/topology_client'
import type { AdminSection } from './admin_section'
import AdminTopologyControls from '../../channel/AdminTopologyControls.vue'
import AdminMembersSection from '../members/AdminMembersSection.vue'
import AdminAuditSection from '../audit/AdminAuditSection.vue'
import AdminMediaDiagnostics from '../media/AdminMediaDiagnostics.vue'
import AdminRolePermissions from '../role_permissions/AdminRolePermissions.vue'
import AdminGuildSettings from '../guild_settings/AdminGuildSettings.vue'
import ReadinessPanel from '../readiness/Panel.vue'

const props = withDefaults(defineProps<{ accountId?: string; categories: TopologyCategory[]; revision: number; section?: AdminSection }>(), { section: 'members' })
const emit = defineEmits<{ topologyChanged: []; 'update:section': [section: AdminSection] }>()
const section = computed({ get: () => props.section, set: (value: AdminSection) => emit('update:section', value) })
const tabs = ref<HTMLElement | null>(null)
let focusFrame: number | null = null
onMounted(() => { focusFrame = window.requestAnimationFrame(() => tabs.value?.querySelector<HTMLButtonElement>('[aria-current="page"]')?.focus()) })
onBeforeUnmount(() => { if (focusFrame !== null) window.cancelAnimationFrame(focusFrame) })
</script>

<template>
  <section class="admin-panel" :class="{ 'admin-panel--members': section === 'members' }" aria-labelledby="admin-panel-title" data-testid="admin-panel">
    <header class="admin-panel-heading"><div><p class="admin-eyebrow">УПРАВЛЕНИЕ ГИЛЬДИЕЙ</p><h1 id="admin-panel-title">Администрирование</h1></div></header>
    <nav ref="tabs" class="admin-section-tabs" aria-label="Разделы администрирования" aria-describedby="admin-section-tabs-hint">
      <button type="button" :aria-current="section === 'guild' ? 'page' : undefined" @click="section = 'guild'">Гильдия</button>
      <button type="button" :aria-current="section === 'members' ? 'page' : undefined" @click="section = 'members'">Участники</button>
      <button type="button" :aria-current="section === 'roles' ? 'page' : undefined" @click="section = 'roles'">Роли</button>
      <button type="button" :aria-current="section === 'channels' ? 'page' : undefined" @click="section = 'channels'">Каналы</button>
      <button type="button" :aria-current="section === 'audit' ? 'page' : undefined" @click="section = 'audit'">Аудит</button>
      <button type="button" :aria-current="section === 'media' ? 'page' : undefined" @click="section = 'media'">Медиа</button>
      <button type="button" :aria-current="section === 'readiness' ? 'page' : undefined" @click="section = 'readiness'">Готовность</button>
    </nav>
    <p id="admin-section-tabs-hint" class="admin-section-tabs-hint">Прокрутите список разделов по горизонтали</p>
    <KeepAlive :max="7">
      <AdminGuildSettings v-if="section === 'guild'" :categories="categories" />
      <AdminMembersSection v-else-if="section === 'members'" />
      <AdminRolePermissions v-else-if="section === 'roles'" />
      <AdminTopologyControls v-else-if="section === 'channels'" :account-id="accountId" :categories="categories" :revision="revision" @changed="emit('topologyChanged')" />
      <AdminAuditSection v-else-if="section === 'audit'" />
      <ReadinessPanel v-else-if="section === 'readiness'" />
      <AdminMediaDiagnostics v-else />
    </KeepAlive>
  </section>
</template>
