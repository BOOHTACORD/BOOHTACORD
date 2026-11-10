import { expect, test } from '@playwright/test'
import { readFileSync } from 'node:fs'
import { chatMembers, chatProfile, chatTopology } from '../../artifacts/design-v2/chat-reference-fixture.mjs'
import { installReferenceTransports } from '../../artifacts/design-v2/reference-live-state.mjs'

const build=JSON.parse(readFileSync(new URL('../../../../contracts/client-build.json',import.meta.url),'utf8')).builds.web
for (const width of [393,1440]) test(`required update blocks interaction and retains draft at ${width}px`, async ({page},testInfo) => {
 await page.setViewportSize({width,height:900})
 await installReferenceTransports(page)
 let release!:()=>void; const wait=new Promise<void>(resolve => {release=resolve})
 await page.route('**/api/v1/**',async route => {
  const path=new URL(route.request().url()).pathname; let body:unknown={}
  if (path.endsWith('/client-updates')) {
   await wait
   body={application_family:'boohtacord',catalog_revision:1,platform:'web',distribution:'browser',channel:'stable',arch:'any',state:'published',target:{release_id:'synthetic-future',release_order:build.release_order+1,minimum_release_order:build.release_order+1,version:'99',native_build:null,priority:'important',summary:'Тестовое обновление',release_notes_url:null,requirements:{supported_arches:['any']},action:{kind:'reload',url:null}}}
  } else if(path.endsWith('/auth/session')) body={account_id:chatProfile.account_id,role:chatProfile.role}
  else if(path.endsWith('/auth/permissions')) body={account_id:chatProfile.account_id,role:chatProfile.role,permissions_revision:1,permissions:{}}
  else if(path.endsWith('/channels')) body=chatTopology
  else if(path.endsWith('/me')) body=chatProfile
  else if(path.endsWith('/members')) body={members:chatMembers}
  else if(path.includes('/messages')) body={messages:[]}
  else if(path.includes('/maintenance')) body={active:false}
  await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)})
 })
 await page.goto('/')
 const draft=page.locator('#message-body'); await expect(draft).toBeVisible(); await draft.fill('synthetic draft')
 release()
 const gate=page.getByRole('dialog',{name:'Требуется обновление'}); await expect(gate).toBeVisible({timeout:15000})
 await expect(gate.getByRole('button',{name:'Обновить страницу'})).toBeVisible()
 await expect(gate.getByRole('button',{name:'Позже'})).toHaveCount(0)
 await expect(draft).toHaveValue('synthetic draft')
 await expect(draft.locator('xpath=ancestor::*[@inert]')).not.toHaveCount(0)
 await expect(gate.getByRole('button',{name:'Обновить страницу'})).toBeFocused()
 await page.keyboard.press('Escape')
 await expect(gate).toBeVisible()
 await expect(draft).toHaveValue('synthetic draft')
 await page.screenshot({path:testInfo.outputPath(`required-${width}.png`),fullPage:true})
})
