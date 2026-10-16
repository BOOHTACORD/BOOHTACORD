import type { Page } from '@playwright/test'
import { channel,dm,messages,own,peer,uid,wire } from './data'
export async function routes(page: Page, kind = 'CHANNEL', admin = false, older = false) {
  const commands: { method:string;path:string;body:unknown }[] = []
  // Synthetic preview is generated in memory; no captured/user media enters the repository.
  const preview = Buffer.from(await page.evaluate(() => {
    const canvas = document.createElement('canvas'); canvas.width=360; canvas.height=180
    const context = canvas.getContext('2d')!
    context.fillStyle='#4343aa'; context.fillRect(0,0,360,180)
    context.fillStyle='white'; context.font='16px sans-serif'; context.fillText('Synthetic image',24,90)
    return canvas.toDataURL('image/png').split(',')[1]!
  }), 'base64')
  let reacted = false
  await page.route('**/api/v1/**', async route => {
    const req=route.request(),url=new URL(req.url()),path=url.pathname,method=req.method()
    if(method!=='GET') commands.push({method,path,body:req.postData()?req.postDataJSON():null})
    if(path.includes('/preview')) return route.fulfill({contentType:'image/png',body:preview})
    if(path.includes('/reactions/')) {reacted=method==='PUT';return route.fulfill({status:204})}
    if(path.includes('/message-reactions')) return route.fulfill({json:{reactions:reacted&&url.searchParams.get('message_ids')?.split(',').includes(uid(1))?[{message_id:uid(1),emoji:'👍',count:1,mine:true}]:[],can_pin:kind==='CHANNEL'&&admin}})
    if(path.includes('/pins/')) return route.fulfill({status:204})
    if(path.endsWith('/auth/session')) return route.fulfill({json:{account_id:own,role:admin?'ADMINISTRATOR':'MEMBER'}})
    if(path.includes('/members/')) return route.fulfill({json:{user_id:path.split('/').at(-1),display_name:path.endsWith(peer)?'Собеседник с длинным именем для проверки':'Алексей — автор',avatar_url:null}})
    if(path.endsWith('/members')) return route.fulfill({json:{members:[]}})
    if(method==='POST'&&path.endsWith('/messages')) return route.fulfill({status:201,json:wire({...messages[0]!,id:uid(50),body:String((req.postDataJSON()??{}).body)},kind)})
    if(method==='PATCH'&&/\/messages\//.test(path)) return route.fulfill({json:{...wire(messages[0]!,kind),body:String(req.postDataJSON().body),revision:2}})
    if(path.endsWith('/messages')) {
      const isOlder=url.searchParams.has('before')
      const items=isOlder?Array.from({length:25},(_,i)=>({...messages[0]!,id:uid(1000+i),clientMessageId:uid(1100+i),body:`Предыдущее сообщение ${i}`,createdAt:new Date(Date.UTC(2026,9,15,9,i)).toISOString()})):messages
      return route.fulfill({json:{messages:items.slice().reverse().map(m=>wire(m,kind)),...(older&&!isOlder?{next_cursor:'previous-page'}:{})}})
    }
    if(path.endsWith('/channels')) return route.fulfill({json:{revision:1,categories:[{id:'general',name:'Общее',position:0,channels:[{id:channel,name:'Общий чат',kind:'TEXT',position:0,admission_closed:false,unread_count:0,mention_count:0}]}]}})
    if(path.endsWith('/direct-messages')) return route.fulfill({json:{direct_messages:[{id:dm,other_participant_id:peer,other_participant_display_name:'Собеседник',created_at:'2026-10-15T10:00:00Z',unread_count:0,mention_count:0}]}})
    return route.fulfill({json:{message_id:null,members:[]}})
  })
  return commands
}
