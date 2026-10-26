<script setup lang="ts">
import { onBeforeUnmount,ref,watch } from 'vue'
import { readPins,pinMessage,type Pin } from './client'
import { subscribeSocialHints,notifyLocalPinChange } from '../reactions/hints'
import { useAuthorDirectory } from '../../identity/author_directory'
import type { SearchTarget } from '../../search/search_target_store'
const props=defineProps<{channelId:string;embedded?:boolean}>(),emit=defineEmits<{open:[target:SearchTarget]}>()
const authors=useAuthorDirectory(),pins=ref<Pin[]>([]),cursor=ref(''),canManage=ref(false),loading=ref(false),busy=ref(false),error=ref('')
let sequence=0,alive=true
async function load(more=false,strict=false):Promise<void>{
  const ticket=++sequence;loading.value=true;error.value=''
  if(!more){pins.value=[];cursor.value='';canManage.value=false}
  try{const page=await readPins(props.channelId,more?cursor.value:undefined);if(!alive||ticket!==sequence)return;pins.value=more?[...pins.value,...page.pins]:page.pins;cursor.value=page.nextCursor??'';canManage.value=page.canManage;for(const pin of page.pins)void authors.ensure(pin.authorId)}
  catch(reason){if(alive&&ticket===sequence){pins.value=[];cursor.value='';canManage.value=false;error.value=reason instanceof Error?reason.message:'Закрепления недоступны.'}if(strict&&alive&&ticket===sequence)throw reason}
  finally{if(alive&&ticket===sequence)loading.value=false}
}
async function remove(id:string):Promise<void>{
  if(busy.value)return;busy.value=true;error.value='';const channel=props.channelId
  try{await pinMessage(channel,id,false);if(alive&&channel===props.channelId){notifyLocalPinChange(channel,id);await load()}}
  catch(reason){if(alive&&channel===props.channelId)error.value=reason instanceof Error?reason.message:'Не удалось снять закрепление.'}
  finally{if(alive)busy.value=false}
}
watch(()=>props.channelId,()=>{void load()},{immediate:true})
const stop=subscribeSocialHints(hint=>{if(!hint||hint.kind==='CHANNEL'&&hint.conversationId===props.channelId&&hint.action==='pins')return load(false,true)})
onBeforeUnmount(()=>{alive=false;sequence++;stop()})
</script>
<template>
  <section class="pin-panel" aria-label="Закреплённые сообщения"><h2 v-if="!embedded">Закреплённые сообщения</h2><div class="result-toolbar"><span class="result-meta">{{pins.length||''}}</span><button class="gc-button gc-button--secondary" type="button" :disabled="loading||busy" @click="load()">Обновить закрепления</button></div><p v-if="loading" role="status">Загрузка…</p><p v-if="error" role="alert">{{error}}</p><p v-else-if="!loading&&!pins.length">Закреплений пока нет.</p>
    <ol class="result-list"><li v-for="pin in pins" :key="pin.messageId" class="result-row"><button class="result-open" type="button" @click="emit('open',{kind:'CHANNEL',conversationId:channelId,messageId:pin.messageId})"><span class="result-meta"><span :title="authors.displayName(pin.authorId)">{{authors.displayName(pin.authorId)}}</span> · <time :datetime="pin.messageCreatedAt">{{new Date(pin.messageCreatedAt).toLocaleString('ru-RU')}}</time></span><p class="result-snippet">{{pin.preview||'Сообщение с вложением'}}</p><span class="result-action-label">К сообщению</span><span class="gc-sr-only">Открыть закреплённое сообщение</span></button><button v-if="canManage" class="gc-button gc-button--secondary" type="button" :disabled="busy||loading" @click="remove(pin.messageId)">Снять закрепление</button></li></ol>
    <button v-if="cursor" class="gc-button gc-button--secondary" type="button" :disabled="loading||busy" @click="load(true)">Ещё закрепления</button>
  </section>
</template>
<style scoped>.pin-panel{padding:8px 16px;display:grid;gap:12px}.pin-panel ol{list-style:none;padding:0}.pin-panel li{border-bottom:1px solid var(--gc-border);padding:12px 0;display:grid;gap:8px}.pin-panel li>button:first-child{text-align:left}.pin-panel p{white-space:pre-wrap;overflow-wrap:anywhere}.pin-panel button{min-height:44px}</style>
