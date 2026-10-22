<script setup lang="ts">
import {ref} from 'vue'
import {useDirectMessageStore} from '../direct_message/direct_message_store'
import {acceptSupportPublication} from './consent'
const store=useDirectMessageStore(),busy=ref(false),error=ref('')
async function accept():Promise<void>{
 if(busy.value)return
 busy.value=true;error.value=''
 try{await acceptSupportPublication(store.supportContact.noticeVersion??0);await store.refreshNavigation()}
 catch{error.value='Не удалось сохранить согласие. Обновите контакт поддержки и повторите.'}
 finally{busy.value=false}
}
</script>
<template>
 <div class="support-publication-consent">
  <button v-if="store.supportContact.mode==='product'" type="button" :disabled="busy||store.supportContact.state!=='available'" @click="accept">{{busy?'Сохраняем…':'Согласен на публикацию'}}</button>
  <p v-else>Общая поддержка отключена для этой установки. Новые сообщения не отправляются.</p>
  <p v-if="error" role="alert">{{error}}</p>
 </div>
</template>
<style scoped>
.support-publication-consent{padding:12px 16px;flex-shrink:0}.support-publication-consent button{min-height:44px;padding:8px 16px;max-width:100%;white-space:normal}
</style>
