<script setup lang="ts">
import { vActionHint } from '../shared/action_hint/directive'
import type { ChannelTopology, TopologyChannel } from './topology_client'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { avatarInitials } from '../design/avatar_initials'
import { computed, nextTick, ref, watch } from 'vue'
import { useAuthorDirectory } from '../identity/author_directory'
import VoiceParticipantStatus from '../voice/VoiceParticipantStatus.vue'
import VoiceRoomRoster from '../voice/VoiceRoomRoster.vue'
import type { VoiceRoomRoster as RoomRoster } from '../voice/voice_roster_client'
import type { VoiceNavigationPresence } from './voice_navigation_presence'
import type { PermissionValues } from '../authorization/permission_keys'
import { categoryActions, channelActions } from './member_topology/action_resolver'
import { useCategoryDisclosure } from './category_disclosure/use_category_disclosure'
import { filterNavigationCategories } from './category_disclosure/preferences'
import CategoryContextMenu from './CategoryContextMenu.vue'

const props = defineProps<{
  accountId: string
  activeVoiceChannelId?: string
  selectedChannelId?: string
  topology: ChannelTopology
  voicePresence: VoiceNavigationPresence | null
  voiceRosters?: RoomRoster[] | null
  permissions?: PermissionValues
}>()

const emit = defineEmits<{
  select: [channel: TopologyChannel]
  createGlobal: []
  createInCategory: [category: ChannelTopology['categories'][number]]
  deleteCategory: [category: ChannelTopology['categories'][number]]
  deleteChannel: [channel: TopologyChannel]
  changed: []
}>()
const authors = useAuthorDirectory()
const channelQuery = ref('')
const categoryContextMenu = ref<{ open: (event: MouseEvent, category: ChannelTopology['categories'][number]) => void } | null>(null)
const disclosure = useCategoryDisclosure(() => props.accountId)
const visibleCategories = computed(() => filterNavigationCategories(props.topology.categories, channelQuery.value))
const favoriteChannels = computed(() => {
  const favorites = new Set(disclosure.favoriteIds())
  return visibleCategories.value.flatMap(({ channels }) => channels).filter(channel => favorites.has(channel.id))
})
watch(() => props.topology.categories.flatMap(({ channels }) => channels.map(({ id }) => id)), ids => disclosure.pruneFavorites(new Set(ids)), { immediate: true })
watch(() => props.topology.categories.map(({ id }) => id), ids => disclosure.pruneCollapsed(new Set(ids)), { immediate: true })
watch(() => props.voicePresence?.members.map((member) => member.id) ?? [], (ids) => {
  ids.filter((id) => id !== 'self').forEach((id) => { void authors.ensure(id) })
}, { immediate: true })

function isConnectedVoice(channel: TopologyChannel): boolean { return channel.kind === 'VOICE' && channel.id === props.activeVoiceChannelId }
function rosterFor(channelId: string): RoomRoster | undefined { return props.voiceRosters?.find((room) => room.channelId === channelId) }
function canCreate(): boolean { return Boolean(props.permissions && (props.permissions['category.create'] || props.permissions['channel.text.create'] || props.permissions['channel.voice.create'])) }
function createInCategory(category: ChannelTopology['categories'][number]): void { emit('createInCategory', category) }
function deleteCategory(category: ChannelTopology['categories'][number]): void { emit('deleteCategory', category) }
async function toggleFavorite(channelId: string, event: MouseEvent): Promise<void> {
  const button = event.currentTarget
  if (!(button instanceof HTMLElement)) {
    disclosure.toggleFavorite(channelId)
    return
  }
  const row = button.closest<HTMLElement>('.channel-row')
  const scrollContainer = row?.closest<HTMLElement>('.nav-content')
  const rowTop = row?.getBoundingClientRect().top
  disclosure.toggleFavorite(channelId)
  await nextTick()
  if (row && scrollContainer && rowTop !== undefined) {
    scrollContainer.scrollTop += row.getBoundingClientRect().top - rowTop
  }
}
</script>

<template>
  <nav class="channel-navigation" aria-label="Разделы и каналы">
    <div class="channel-navigation-actions"><span>Каналы</span><button v-action-hint v-if="canCreate()" type="button" aria-label="Создать раздел или канал" @click="emit('createGlobal')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg></button></div>
    <label class="channel-search"><span class="gc-sr-only">Поиск каналов</span><input v-model="channelQuery" type="search" placeholder="Найти канал" autocomplete="off" aria-label="Поиск каналов"></label>
    <section v-if="favoriteChannels.length" class="channel-category channel-favorites" aria-label="Избранные каналы">
      <h2><span class="channel-favorites-title">Избранное</span></h2>
      <button v-for="channel in favoriteChannels" :key="channel.id" type="button" class="channel-button channel-favorite-link" :class="{ selected: props.selectedChannelId === channel.id, 'voice-connected': isConnectedVoice(channel) }" :aria-current="props.selectedChannelId === channel.id ? 'page' : undefined" @click="emit('select', channel)">
        <span class="channel-icon" aria-hidden="true">{{ channel.kind === 'TEXT' ? '#' : '◖' }}</span><span class="channel-name">{{ channel.name }}</span><span v-if="isConnectedVoice(channel)" class="channel-connected-mark" role="img" aria-label="Подключено к голосу">✓</span><span v-if="channel.kind === 'TEXT' && channel.unreadCount" class="channel-state" :aria-label="`Непрочитанных сообщений: ${channel.unreadCount}`">{{ channel.unreadCount }}</span><span v-if="channel.kind === 'TEXT' && channel.mentionCount" class="channel-state" :aria-label="`Упоминаний: ${channel.mentionCount}`">@{{ channel.mentionCount }}</span><span class="channel-favorite-parent">{{ props.topology.categories.find(category => category.channels.some(item => item.id === channel.id))?.name }}</span>
      </button>
    </section>
    <section v-for="category in visibleCategories" :key="category.id" class="channel-category" @contextmenu.stop.prevent="categoryContextMenu?.open($event, category)">
      <h2><button v-action-hint="category.name" class="channel-category-disclosure" type="button" :aria-label="`${disclosure.isOpen(category.id) ? 'Свернуть' : 'Развернуть'} раздел ${category.name}`" :aria-expanded="disclosure.isOpen(category.id)" @click="disclosure.toggle(category.id)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="m8 10 4 4 4-4" /></svg><span>{{ category.name }}</span></button><span v-if="props.permissions" class="channel-category-actions">
        <button v-action-hint v-if="categoryActions(props.permissions, category.channels.length === 0).createText || categoryActions(props.permissions, category.channels.length === 0).createVoice" type="button" :aria-label="`Создать канал в разделе ${category.name}`" @click="emit('createInCategory', category)"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg></button>
        <button v-action-hint v-if="categoryActions(props.permissions, category.channels.length === 0).delete" type="button" :aria-label="`Действия с разделом ${category.name}`" @click="emit('deleteCategory', category)">⋯</button>
      </span></h2>
      <p v-if="disclosure.isOpen(category.id) && category.channels.length === 0" class="empty-category">Нет каналов</p>
      <template v-for="channel in disclosure.isOpen(category.id) || channelQuery.trim() ? category.channels : []" :key="channel.id">
        <div class="channel-row" @contextmenu.stop.prevent><button
          class="channel-button"
          :class="{ selected: props.selectedChannelId === channel.id, 'voice-connected': isConnectedVoice(channel) }"
          :aria-current="props.selectedChannelId === channel.id ? 'page' : undefined"
          type="button"
          @click="emit('select', channel)"
        >
          <span class="channel-icon" aria-hidden="true">
            <svg v-if="channel.kind === 'TEXT'" viewBox="0 0 24 24"><path d="M5 9h14M4 15h14M11 3 7 21M17 3l-4 18" /></svg>
            <svg v-else viewBox="0 0 24 24"><path d="m11 5-6 4H2v6h3l6 4V5ZM15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14" /></svg>
          </span>
          <span class="channel-name">{{ channel.name }}</span><span v-if="isConnectedVoice(channel)" class="channel-connected-mark" role="img" aria-label="Подключено к голосу">✓</span>
          <span v-if="channel.kind === 'TEXT' && channel.unreadCount" class="channel-state" :aria-label="`Непрочитанных сообщений: ${channel.unreadCount}`">{{ channel.unreadCount }}</span>
          <span v-if="channel.kind === 'TEXT' && channel.mentionCount" class="channel-state" :aria-label="`Упоминаний: ${channel.mentionCount}`">@{{ channel.mentionCount }}</span>
          <span v-if="channel.kind === 'VOICE' && (props.voicePresence?.channelId === channel.id ? props.voicePresence.memberCount > 0 : (rosterFor(channel.id)?.participants.length ?? 0) > 0)" class="channel-member-count" :aria-label="`Участников в голосовом канале: ${props.voicePresence?.channelId === channel.id ? props.voicePresence.memberCount : rosterFor(channel.id)?.participants.length}`">{{ props.voicePresence?.channelId === channel.id ? props.voicePresence.memberCount : rosterFor(channel.id)?.participants.length }}</span>
          <span v-if="channel.admissionClosed" class="channel-state">Вход закрыт</span>
        </button><button v-action-hint class="channel-favorite-toggle" type="button" :aria-label="`${disclosure.isFavorite(channel.id) ? 'Убрать из избранного' : 'Добавить в избранное'}: ${channel.name}`" :aria-pressed="disclosure.isFavorite(channel.id)" @click.stop="toggleFavorite(channel.id, $event)">{{ disclosure.isFavorite(channel.id) ? '★' : '☆' }}</button><button v-action-hint v-if="props.permissions && channelActions(props.permissions, channel.kind).delete" class="channel-actions-button" type="button" :aria-label="`Действия с каналом ${channel.name}`" @click.stop="emit('deleteChannel', channel)">⋯</button></div>
        <ul v-if="props.voicePresence && props.voicePresence.channelId === channel.id" class="voice-member-list" aria-label="Участники подключённого голосового канала" data-testid="voice-member-rows">
          <li v-for="member in props.voicePresence.members" :key="member.id" class="voice-member-row" :class="{ 'is-speaking': member.isSpeaking }">
            <span class="voice-member-avatar" :style="{ backgroundColor: avatarBackground(member.id), color: avatarForeground(member.id) }" aria-hidden="true"><img v-if="authors.avatarUrl(member.id)" :src="authors.avatarUrl(member.id)" alt=""><template v-else>{{ avatarInitials(member.name) }}</template></span>
            <span class="voice-member-name">{{ member.name }}</span>
            <span v-if="member.screenSharing" class="voice-member-share" role="img" aria-label="Показывает экран" title="Показывает экран"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5h16v11H4zM9 20h6m-3-4v4" /></svg></span>
            <VoiceParticipantStatus compact :microphone-muted="member.microphoneMuted" :microphone-unavailable="member.microphoneUnavailable" :speaking="member.speaking" />
          </li>
        </ul>
        <VoiceRoomRoster v-else-if="channel.kind === 'VOICE' && rosterFor(channel.id)?.participants.length" :roster="rosterFor(channel.id)!" compact />
        </template>
    </section>
    <p v-if="channelQuery.trim() && !visibleCategories.length" class="channel-search-empty" role="status">Каналы не найдены</p>
    <CategoryContextMenu ref="categoryContextMenu" :topology="props.topology" :permissions="props.permissions" @create-global="emit('createGlobal')" @create-in-category="createInCategory" @delete-category="deleteCategory" @changed="emit('changed')" />
  </nav>
</template>
