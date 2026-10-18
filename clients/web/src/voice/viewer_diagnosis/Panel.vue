<script setup lang="ts">
import { computed,onBeforeUnmount,onMounted,ref,watch } from 'vue'
import { diagnose, resumeFirstFrameDeadline, shouldAutomaticallyRecover } from './model'
import { buildBundle,parseBundle,type Sample } from './bundle'
import { createDiagnosisSeries } from './series'
import type { ScreenReceiverMetrics } from '../screen_receiver_diagnostics'
import type { ScreenDiagnostics } from '../screen_diagnostics'
const props=defineProps<{selectedId:string|null;ended:boolean;hasAudio:boolean;local:boolean;publisherPaused?:boolean;autoplayBlocked?:boolean;subscriptionFailed?:boolean;stageVisible?:()=>boolean;videoReady:boolean;presentedFps:number|null;presentedFrames?:number|null;sampledAt:number|null;metrics:ScreenReceiverMetrics|null;source?:ScreenDiagnostics}>()
const emit=defineEmits<{retry:[];autoRetry:[];refresh:[];choose:[]}>()
const now=ref(Date.now()),selectedAt=ref(Date.now()),visible=ref(true),error=ref(''),help=ref(false),second=ref<Sample[]|null>(null),automaticRecoveryUsed=ref(false),recoverySuppressed=ref(false)
const stableHasAudio=ref(props.hasAudio)
let audioPresenceTimer:ReturnType<typeof setTimeout>|null=null
watch(()=>[props.selectedId,props.hasAudio] as const,([selectedId,hasAudio],[previousSelectedId])=>{
  if(audioPresenceTimer)clearTimeout(audioPresenceTimer)
  audioPresenceTimer=null
  if(selectedId!==previousSelectedId){stableHasAudio.value=hasAudio;return}
  audioPresenceTimer=setTimeout(()=>{stableHasAudio.value=hasAudio;audioPresenceTimer=null},1200)
})
const diagnosis=computed(()=>diagnose({...props,hasAudio:stableHasAudio.value,selected:Boolean(props.selectedId),selectedAt:selectedAt.value,now:now.value,visible:visible.value}))
// Receiver samples can arrive between the panel's one-second clock ticks.
watch(()=>props.sampledAt,()=>{now.value=Math.max(now.value,Date.now())},{flush:'sync'})
const series=createDiagnosisSeries(()=>{
  const fresh=props.sampledAt!==null&&now.value-props.sampledAt>=0&&now.value-props.sampledAt<=6000
  const source=props.local&&props.source?.sampledAt!==undefined&&now.value-props.source.sampledAt>=0&&now.value-props.source.sampledAt<=6000?props.source:null
  return {state:diagnosis.value.state,captureFps:source?.profileCheck?.captureFps,encodedFps:source?.measured?.framesPerSecond,decodedFps:fresh?props.metrics?.decodedFps:null,presentedFps:visible.value?props.presentedFps:null,bitrateKbps:fresh?props.metrics?.bitrateKbps:null,rttMs:source?.roundTripTimeMs ?? null,sampleAgeMs:props.sampledAt===null?null:now.value-props.sampledAt,capturedFrames:source?.capturedFrames,encodedFrames:source?.encodedFrames,decodedFrames:fresh?props.metrics?.decodedFrames:null,presentedFrames:visible.value?props.presentedFrames:null}
})
function recoveryInput(){return {...props,selected:Boolean(props.selectedId),selectedAt:selectedAt.value,now:now.value,visible:visible.value&&stageIsVisible(),automaticRecoveryAttempted:automaticRecoveryUsed.value||recoverySuppressed.value}}
function attemptAutomaticRecovery():void {if(props.autoplayBlocked) recoverySuppressed.value=true;if(!shouldAutomaticallyRecover(recoveryInput()))return;automaticRecoveryUsed.value=true;selectedAt.value=Date.now();now.value=selectedAt.value;emit('autoRetry')}
function action():void {const value=diagnosis.value.action;if(value==='publisher') help.value=!help.value;else if(value==='retry'){selectedAt.value=Date.now();now.value=selectedAt.value;emit('retry')}else if(value==='refresh') emit('refresh');else if(value==='choose') emit('choose')}
function exportBundle():void {
  const value=buildBundle(series.samples.value,second.value ?? undefined)
  const url=URL.createObjectURL(new Blob([JSON.stringify(value,null,2)],{type:'application/json'})),link=document.createElement('a')
  link.href=url;link.download='boohtacord-viewer-test-run.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000)
}
async function importSecond(event:Event):Promise<void> {
  const input=event.target as HTMLInputElement,file=input.files?.[0];second.value=null;error.value=''
  try {if(!file||file.size>32768) throw new Error('Выберите диагностический JSON до 32 КиБ.');const bundle=parseBundle(await file.text());if(bundle.receivers.length!==1) throw new Error('Нужен файл одного второго приёмника.');second.value=bundle.receivers[0].samples}
  catch(cause){error.value=cause instanceof Error?cause.message:'Некорректная диагностика.'}finally{input.value=''}
}
watch(()=>props.selectedId,()=>{selectedAt.value=Date.now();if(!deadlineActive)suspendedAt=selectedAt.value;automaticRecoveryUsed.value=false;recoverySuppressed.value=false;series.clear();second.value=null;help.value=false})
let timer:ReturnType<typeof setInterval>|null=null,suspendedAt:number|null=null,deadlineActive=false
function stageIsVisible():boolean {return document.visibilityState==='visible'&&(props.stageVisible?.()??true)}
function updateVisibility():void {const at=Date.now(),nextVisible=stageIsVisible(),nextActive=nextVisible&&!props.publisherPaused;if(nextActive&&!deadlineActive&&suspendedAt!==null){selectedAt.value=resumeFirstFrameDeadline(selectedAt.value,suspendedAt,at);suspendedAt=null}else if(!nextActive&&deadlineActive)suspendedAt=at;deadlineActive=nextActive;visible.value=nextVisible;now.value=at;attemptAutomaticRecovery()}
watch([()=>props.publisherPaused,()=>props.stageVisible],updateVisibility)
watch([()=>props.subscriptionFailed,()=>props.autoplayBlocked,()=>props.videoReady,visible],attemptAutomaticRecovery)
onMounted(()=>{updateVisibility();document.addEventListener('visibilitychange',updateVisibility);timer=setInterval(updateVisibility,1000);attemptAutomaticRecovery()})
onBeforeUnmount(()=>{if(timer) clearInterval(timer);if(audioPresenceTimer)clearTimeout(audioPresenceTimer);document.removeEventListener('visibilitychange',updateVisibility);series.stop()})
</script>
<template>
  <section class="screen-diagnosis" aria-label="Диагностика просмотра">
    <p role="status" aria-live="polite">{{ diagnosis.message }}</p>
    <button v-if="diagnosis.action !== 'none'" type="button" :aria-expanded="diagnosis.action === 'publisher' ? help : undefined" :aria-controls="diagnosis.action === 'publisher' ? 'screen-audio-help' : undefined" @click="action">{{ diagnosis.action === 'publisher' && help ? 'Скрыть инструкцию' : diagnosis.label }}</button>
    <p v-show="help" id="screen-audio-help">Попросите ведущего заново выбрать источник и включить передачу звука. Звук должен поддерживаться выбранным источником и браузером.</p>
    <details><summary>Локальный диагностический прогон</summary>
      <p>До 60 секунд и 30 измерений. Capture/encoded доступны только у источника, decoded/presented — у приёмника. Неизвестные значения, включая RTT, остаются неизвестными.</p>
      <p>Captured/encoded/decoded/presented frames — наблюдаемые счётчики; capture FPS — текущий параметр захвата, не измеренная частота кадров.</p>
      <p>Файл содержит только состояния и числовые измерения. Он не отправляется на сервер. Для сравнения выберите файл второго приёмника того же прогона.</p>
      <button type="button" :disabled="series.collecting.value" @click="series.begin">Снять минуту измерений</button>
      <button v-if="series.collecting.value" type="button" @click="series.stop">Остановить измерения</button>
      <p role="status">Образцов: {{ series.samples.value.length }} / 30{{ second ? '; второй приёмник добавлен' : '' }}</p>
      <label>Файл второго приёмника<input type="file" accept="application/json,.json" @change="importSecond"></label>
      <button type="button" :disabled="!series.samples.value.length || series.collecting.value" @click="exportBundle">Скачать диагностический JSON</button>
      <p v-if="error" role="alert">{{ error }}</p>
    </details>
  </section>
</template>
