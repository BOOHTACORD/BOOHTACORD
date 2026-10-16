<script setup lang="ts">
import { onBeforeUnmount,ref,watch } from 'vue'
import { emojis,setReaction,type Emoji,type Reaction,type ReactionKind } from './client'
import { readReactionFor } from './batch'
import { subscribeSocialHints } from './hints'
const props=defineProps<{kind:ReactionKind;conversationId:string;messageId:string}>()
const rows=ref<Reaction[]>([]),canPin=ref(false),loading=ref(false),busy=ref(false),error=ref('')
let sequence=0,alive=true
const key=()=>`${props.kind}:${props.conversationId}:${props.messageId}`
const mine=(emoji:Emoji)=>rows.value.find(row=>row.emoji===emoji)?.mine??false
const count=(emoji:Emoji)=>rows.value.find(row=>row.emoji===emoji)?.count??0
async function load():Promise<void> {
  const ticket=++sequence;loading.value=true;error.value=''
  try { const page=await readReactionFor(props.kind,props.conversationId,props.messageId);if(!alive||ticket!==sequence)return;rows.value=page.rows;canPin.value=page.canPin }
  catch(reason){if(alive&&ticket===sequence){rows.value=[];canPin.value=false;error.value=reason instanceof Error?reason.message:'Реакции недоступны.'}}
  finally{if(alive&&ticket===sequence)loading.value=false}
}
async function toggle(emoji:Emoji):Promise<void> {
  if(busy.value||loading.value||error.value)return
  const target=key(),present=!mine(emoji);busy.value=true
  try {await setReaction(props.kind,props.conversationId,props.messageId,emoji,present);if(alive&&key()===target)await load()}
  catch(reason){if(alive&&key()===target)error.value=reason instanceof Error?reason.message:'Не удалось изменить реакцию.'}
  finally{if(alive)busy.value=false}
}
watch(()=>[props.kind,props.conversationId,props.messageId],()=>{rows.value=[];canPin.value=false;void load()},{immediate:true})
const stop=subscribeSocialHints(hint=>{if(!hint||hint.kind===props.kind&&hint.conversationId===props.conversationId&&hint.messageId===props.messageId)void load()})
onBeforeUnmount(()=>{alive=false;sequence++;stop()})
</script>
<template>
  <div class="reaction-tools" role="group" aria-label="Реакции на сообщение">
    <div v-if="!loading&&!error&&rows.some(row=>row.count>0)" class="reaction-counts" role="group" aria-label="Установленные реакции">
      <button v-for="reaction in rows.filter(row=>row.count>0)" :key="reaction.emoji" type="button" :disabled="busy" :aria-label="`Реакция ${reaction.emoji}`" :aria-pressed="reaction.mine" @click="toggle(reaction.emoji)">{{reaction.emoji}} <span>{{reaction.count}}</span></button>
    </div>
    <details class="reaction-picker">
      <summary>{{ canPin ? 'Реакции и закрепление' : 'Реакции' }}</summary>
      <div class="reaction-palette">
        <button v-for="emoji in emojis" :key="emoji" type="button" :disabled="loading||busy||Boolean(error)" :aria-label="`Реакция ${emoji}`" :aria-pressed="mine(emoji)" @click="toggle(emoji)">{{emoji}}<span v-if="!loading&&!error&&count(emoji)"> {{count(emoji)}}</span></button>
        <slot :can-pin="canPin&&!loading&&!error" />
      </div>
    </details>
    <span v-if="loading" role="status">Загрузка реакций…</span><span v-if="error" role="alert">{{error}} <button type="button" :disabled="loading||busy" @click="load()">Обновить реакции</button></span>
  </div>
</template>
<style scoped>
.reaction-tools { display: flex; gap: 6px; flex-wrap: wrap; align-items: center; margin-top: 2px; font-size: 0.75rem; }
.reaction-counts, .reaction-palette { display: flex; gap: 4px; flex-wrap: wrap; align-items: center; }
.reaction-picker { min-width: 0; max-width: 100%; }
summary { width: fit-content; min-height: 28px; align-content: center; border-radius: 4px; padding: 2px 4px; color: var(--gc-text-muted); cursor: pointer; }
.reaction-palette { margin-top: 2px; }
.reaction-tools button { min-height: 28px; border: 1px solid var(--gc-border); border-radius: 14px; background: transparent; color: inherit; padding: 3px 8px; }
.reaction-tools button[aria-pressed="true"] { border-color: var(--gc-accent); background: var(--gc-panel); }
summary:hover { color: var(--gc-text-primary); background: var(--gc-surface-hover); }
summary:focus-visible, .reaction-tools button:focus-visible { outline: 2px solid var(--gc-focus); outline-offset: 2px; }
@media (max-width:600px),(hover:none),(pointer:coarse) { summary, .reaction-tools button { min-width: 44px; min-height: 44px; } }
</style>
