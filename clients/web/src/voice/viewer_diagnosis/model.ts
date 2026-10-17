export const firstFrameTimeoutMs=5000
export const states=['idle','ended','background','publisher_paused','autoplay_blocked','subscription_failed','connecting','no_first_frame','stale_metrics','frozen','no_audio','playing'] as const
export type DiagnosisState=typeof states[number]
export type DiagnosisAction='none'|'retry'|'refresh'|'choose'|'publisher'
export interface Input {selected:boolean;ended:boolean;visible:boolean;publisherPaused?:boolean;autoplayBlocked?:boolean;subscriptionFailed?:boolean;automaticRecoveryAttempted?:boolean;local:boolean;hasAudio:boolean;videoReady:boolean;presentedFps:number|null;sampledAt:number|null;selectedAt:number;now:number}
export function resumeFirstFrameDeadline(selectedAt:number,suspendedAt:number,resumedAt:number):number {return resumedAt>=suspendedAt?selectedAt+resumedAt-suspendedAt:selectedAt}
export function shouldAutomaticallyRecover(input:Input):boolean {
  if(!input.selected||input.ended||!input.visible||input.local||input.publisherPaused||input.autoplayBlocked||input.automaticRecoveryAttempted)return false
  return Boolean(!input.videoReady&&(input.subscriptionFailed||input.now>=input.selectedAt&&input.now-input.selectedAt>=firstFrameTimeoutMs))
}
export function diagnose(input:Input):{state:DiagnosisState;message:string;action:DiagnosisAction;label:string} {
  if(input.ended) return {state:'ended',message:'Демонстрация завершена.',action:'choose',label:'Выбрать другую демонстрацию'}
  if(!input.selected) return {state:'idle',message:'Выберите демонстрацию.',action:'none',label:''}
  if(!input.visible) return {state:'background',message:'Просмотр скрыт или окно в фоне. Ожидание первого кадра приостановлено.',action:'none',label:''}
  if(input.publisherPaused) return {state:'publisher_paused',message:'Источник приостановил передачу видео.',action:'none',label:''}
  if(input.autoplayBlocked) return {state:'autoplay_blocked',message:'Браузер заблокировал автозапуск. Нажмите кнопку, чтобы разрешить воспроизведение.',action:'retry',label:'Разрешить воспроизведение'}
  if(input.subscriptionFailed) return {state:'subscription_failed',message:'Не удалось подписаться на демонстрацию.',action:'retry',label:'Повторить подключение к демонстрации'}
  if(!input.videoReady) return input.now-input.selectedAt<firstFrameTimeoutMs
    ? {state:'connecting',message:'Ожидаем первый кадр.',action:'none',label:''}
    : {state:'no_first_frame',message:'Первый кадр пока не получен.',action:'retry',label:'Повторить подключение к демонстрации'}
  if(input.presentedFps===0) return {state:'frozen',message:'Показанные кадры не обновляются. Это не определяет причину на источнике.',action:'retry',label:'Повторить подключение к демонстрации'}
  if(!input.hasAudio) return {state:'no_audio',message:'Источник не публикует аудиодорожку.',action:'publisher',label:'Как добавить звук'}
  if(!input.local&&(input.sampledAt===null||input.now-input.sampledAt>6000||input.now<input.sampledAt)) return {state:'stale_metrics',message:'Данные о приёме отсутствуют или устарели. Причина качества не определена.',action:'refresh',label:'Обновить измерения'}
  return {state:'playing',message:'Демонстрация воспроизводится.',action:'none',label:''}
}
