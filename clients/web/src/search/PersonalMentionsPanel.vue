<script setup lang="ts">
import { onMounted, watch } from 'vue'
import { useAuthorDirectory } from '../identity/author_directory'
import { createMentionInboxController } from './mention_inbox_controller'
import type { MentionInboxItem } from './mentions_inbox_client'

const props = defineProps<{ channelLabels: Record<string, string>; directMessageLabels: Record<string, string> }>()
const emit = defineEmits<{ open: [item: MentionInboxItem] }>()
const authors = useAuthorDirectory()
const inbox = createMentionInboxController()
watch(inbox.mentions, (items) => { for (const item of items) void authors.ensure(item.authorId) })
function label(item: MentionInboxItem): string {
  return item.kind === 'CHANNEL' ? props.channelLabels[item.conversationId] ?? 'Текстовый канал' : props.directMessageLabels[item.conversationId] ?? 'Личный диалог'
}
function date(value: string): string { return new Intl.DateTimeFormat('ru-RU', { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }).format(new Date(value)) }
onMounted(() => { void inbox.refresh() })
</script>

<template>
  <section class="mention-inbox" aria-label="Личные упоминания" data-testid="mention-inbox">
    <div class="mention-inbox-toolbar result-toolbar"><span class="result-meta" :aria-busy="inbox.loading.value"><span class="gc-sr-only">Упоминания только для вас. </span>{{ inbox.mentions.value.length || '' }}</span><button class="gc-button gc-button--secondary" type="button" :disabled="inbox.loading.value" @click="inbox.refresh">Обновить</button></div>
    <p v-if="inbox.error.value" class="search-error" role="alert">{{ inbox.error.value }}</p>
    <p v-else-if="inbox.loading.value && !inbox.mentions.value.length" class="search-status search-status--visible" role="status">Загружаем упоминания…</p>
    <p v-else-if="!inbox.mentions.value.length" class="search-status search-status--visible" role="status">Пока нет упоминаний.</p>
    <ol v-else class="search-results" aria-label="Список личных упоминаний">
      <li v-for="item in inbox.mentions.value" :key="`${item.kind}:${item.messageId}`" class="search-result result-row">
        <article><header class="result-meta"><span class="result-source" :title="label(item)">{{ label(item) }}</span><time :datetime="item.createdAt">{{ date(item.createdAt) }}</time></header>
          <div class="search-result-author"><strong :title="authors.displayName(item.authorId)">{{ authors.displayName(item.authorId) }}</strong></div>
          <button type="button" :aria-label="`Перейти к упоминанию от ${authors.displayName(item.authorId)}`" @click="emit('open', item)">К сообщению</button>
        </article>
      </li>
    </ol>
    <button v-if="inbox.nextCursor.value" class="search-more gc-button gc-button--secondary" type="button" :disabled="inbox.loading.value" @click="inbox.loadMore">Показать ещё</button>
  </section>
</template>
