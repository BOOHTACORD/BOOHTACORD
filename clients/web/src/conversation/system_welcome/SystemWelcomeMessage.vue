<script setup lang="ts">
import MessageTimestamp from '../MessageTimestamp.vue'
import { computed, watch } from 'vue'
import { useAuthorDirectory } from '../../identity/author_directory'
const props = defineProps<{ body: string; authorId: string; createdAt?: string; deleted?: boolean; canDelete?: boolean }>()
const emit = defineEmits<{ remove: [] }>()
const authors = useAuthorDirectory()
const name = computed(() => authors.displayName(props.authorId))
watch(() => props.authorId, id => { void authors.ensure(id) }, { immediate: true })
function remove(): void { if (window.confirm('Удалить это системное приветствие?')) emit('remove') }
</script>
<template>
  <article class="system-welcome-message" aria-label="Системное приветствие">
    <span aria-hidden="true">✦</span>
    <p v-if="deleted">Системное приветствие удалено.</p>
    <p v-else><span class="message-mention" :data-user-id="authorId">@{{ name }}</span> {{ body }}</p>
    <MessageTimestamp v-if="createdAt" :created-at="createdAt" />
    <button v-if="canDelete && !deleted" type="button" aria-label="Удалить системное приветствие" @click="remove">Удалить</button>
  </article>
</template>
<style scoped>
.system-welcome-message { display: flex; align-items: baseline; flex-wrap: wrap; gap: 8px; padding: 10px 16px; color: var(--gc-text-muted); overflow-wrap: anywhere; }
p { flex: 1; min-width: 0; margin: 0; } time { font-size: 0.75rem; white-space: nowrap; }
.message-mention { color: var(--gc-accent-text); }
.system-welcome-message > button { min-height: var(--gc-size-control-sm); border: 1px solid var(--gc-danger); border-radius: var(--gc-radius-sm); padding: 0 var(--gc-space-2); color: var(--gc-danger); background: var(--gc-danger-bg); font: inherit; }
@media (hover: none), (pointer: coarse), (max-width: 600px) {
  .system-welcome-message > button { min-height: var(--gc-size-touch); }
}
</style>
