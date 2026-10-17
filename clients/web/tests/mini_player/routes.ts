import type { Page } from '@playwright/test'
import { routes } from '../chat_rhythm/routes'
import { dm, messages, uid, wire } from '../chat_rhythm/data'
export async function miniRoutes(page: Page) {
 await routes(page)
 await page.route('**/api/v1/direct-messages/*/messages*',route=>{
  const request=route.request()
  if(request.method()==='POST')return route.fulfill({status:201,json:wire({...messages[0]!,id:uid(50),body:request.postDataJSON().body},'DIRECT_MESSAGE')})
  return route.fulfill({json:{messages:messages.filter(m=>!m.kind).slice().reverse().map(m=>wire(m,'DIRECT_MESSAGE'))}})
 })
}
