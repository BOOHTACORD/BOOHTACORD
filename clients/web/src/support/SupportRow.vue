<script setup lang="ts">
import { computed } from 'vue'
import type { SupportContact } from './contact'
import type { DirectMessageListItem } from '../direct_message/direct_message_navigation_client'
const props=defineProps<{contact:SupportContact;directMessages:DirectMessageListItem[];selectedId?:string;busy?:boolean}>()
const emit=defineEmits<{open:[]}>()
const existing=computed(()=>props.directMessages.find(item=>item.otherParticipantId===props.contact.accountId))
</script>
<template>
 <button v-if="contact.state==='available'" class="channel-button support-row" :class="{selected:existing && selectedId===existing.id}" :aria-current="existing && selectedId===existing.id?'page':undefined" :disabled="busy" :aria-busy="busy||undefined" type="button" @click="emit('open')">
  <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 4h14v12H9l-4 4V4Z"/><path d="M10 8a2 2 0 0 1 4 0c0 1-2 1-2 3M12 13h.01"/></svg>
  <span class="dm-identity"><span class="channel-name">Поддержка</span><small>Поддержка этого сервера · закреплено</small></span>
  <span v-if="existing?.unreadCount" class="channel-state" :aria-label="`Непрочитанных личных сообщений: ${existing.unreadCount}`">{{existing.unreadCount}}</span>
  <span v-if="existing?.mentionCount" class="channel-state" :aria-label="`Упоминаний в личном диалоге: ${existing.mentionCount}`">@{{existing.mentionCount}}</span>
 </button>
</template>
<style scoped>
.support-row {min-height:48px;width:100%;text-align:left;}
.support-row svg {width:28px;height:28px;flex:0 0 28px;fill:none;stroke:currentColor;stroke-width:1.5;}
.support-row small {white-space:normal;overflow-wrap:anywhere;}
</style>
