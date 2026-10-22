import {tracedFetch} from '../telemetry/client_tracing'
import {apiBaseUrl} from '../config/runtime'
import type {DirectMessageRequest} from '../direct_message/direct_message_client'
export async function acceptSupportPublication(version:number,request:DirectMessageRequest=tracedFetch):Promise<void>{
 if(!Number.isSafeInteger(version)||version<1)throw new Error('Обновите контакт поддержки.')
 const response=await request(`${apiBaseUrl}/support/consent`,{method:'POST',credentials:'same-origin',headers:{'content-type':'application/json'},body:JSON.stringify({notice_version:version})})
 if(!response.ok)throw new Error('Не удалось сохранить согласие. Обновите контакт поддержки и повторите.')
}
