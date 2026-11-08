<script setup lang="ts">
import { dismissActionHint, vActionHint } from '../shared/action_hint/directive'
import { onBeforeUnmount, onMounted, useId } from 'vue'

import { useConversationOverflowMenu } from './conversation_overflow_menu'

const props = withDefaults(defineProps<{ showMembers?: boolean; membersOpen?: boolean; showFiles?: boolean; menuLabel?: string }>(), {
  showMembers: false,
  membersOpen: false,
  menuLabel: 'Действия переписки',
})
const emit = defineEmits<{ toggleMembers: []; files: [] }>()
defineExpose({ focus: () => trigger.value?.focus() })
const menuId = useId()
const { expanded, root, trigger, menu, toggle, onOutside, onFocusOut, onKeys, close, toggleMembers } =
  useConversationOverflowMenu(() => emit('toggleMembers'))

function toggleMembersFromMenu(): void { dismissActionHint(trigger.value); toggleMembers() }
function toggleMenu(): void { dismissActionHint(trigger.value); toggle() }
function openFilesFromMenu(): void { dismissActionHint(trigger.value); close(); emit('files') }

onMounted(() => document.addEventListener('pointerdown', onOutside))
onBeforeUnmount(() => document.removeEventListener('pointerdown', onOutside))
</script>

<template>
  <div ref="root" class="conversation-overflow" :class="{ 'conversation-overflow--expanded': expanded }" @keydown="onKeys" @focusout="onFocusOut">
    <button v-action-hint ref="trigger" class="header-action conversation-overflow__trigger" type="button"
      aria-label="Другие действия" aria-haspopup="menu" :aria-expanded="expanded"
      :aria-controls="menuId" @click="toggleMenu">⋯</button>
    <div v-show="expanded" :id="menuId" ref="menu" class="conversation-overflow__menu" role="menu" :aria-label="props.menuLabel">
      <button v-if="props.showFiles" type="button" role="menuitem" @click="openFilesFromMenu">Файлы беседы</button>
      <button v-if="props.showMembers" type="button" role="menuitem" :aria-expanded="membersOpen" aria-controls="members-panel" @click="toggleMembersFromMenu">{{ props.membersOpen ? 'Скрыть участников' : 'Показать участников' }}</button>
    </div>
  </div>
</template>
