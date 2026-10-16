<script setup lang="ts">
import { vActionHint } from '../shared/action_hint/directive'
import { onBeforeUnmount, onMounted, useId } from 'vue'

import { useConversationOverflowMenu } from './conversation_overflow_menu'

const props = withDefaults(defineProps<{ showMembers?: boolean; membersOpen?: boolean; showFiles?: boolean; menuLabel?: string }>(), {
  showMembers: false,
  membersOpen: false,
  menuLabel: 'Действия переписки',
})
const emit = defineEmits<{ search: []; toggleMembers: []; files: [] }>()
const menuId = useId()
const { expanded, root, trigger, menu, toggle, onOutside, onFocusOut, onKeys, openSearch, toggleMembers } =
  useConversationOverflowMenu(() => emit('search'), () => emit('toggleMembers'))

onMounted(() => document.addEventListener('pointerdown', onOutside))
onBeforeUnmount(() => document.removeEventListener('pointerdown', onOutside))
</script>

<template>
  <div ref="root" class="conversation-overflow" @keydown="onKeys" @focusout="onFocusOut">
    <button v-action-hint ref="trigger" class="header-action conversation-overflow__trigger" type="button"
      aria-label="Другие действия" aria-haspopup="menu" :aria-expanded="expanded"
      :aria-controls="menuId" @click="toggle">⋯</button>
    <div v-show="expanded" :id="menuId" ref="menu" class="conversation-overflow__menu" role="menu" :aria-label="props.menuLabel">
      <button type="button" role="menuitem" @click="openSearch">Найти сообщение</button>
      <button v-if="props.showFiles" type="button" role="menuitem" @click="expanded = false; emit('files')">Файлы беседы</button>
      <button v-if="props.showMembers" type="button" role="menuitem" @click="toggleMembers">{{ props.membersOpen ? 'Скрыть участников' : 'Показать участников' }}</button>
    </div>
  </div>
</template>
