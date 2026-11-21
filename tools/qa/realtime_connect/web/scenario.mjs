import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { chromium, api, status, channel, origin, expect } from '../../client_lifecycle/request.mjs'
import { observe } from './observe.mjs'
import { faults, healthy } from './cases.mjs'
import { cancellation } from './cancellation.mjs'
import { guestFaults } from './guest.mjs'
import { writeFailure } from './failure.mjs'

assert.equal(origin,'https://localhost:4910')
const input = JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
const browser = await chromium.launch({headless:true,args:['--allow-loopback-in-peer-connection']})
let stage='startup'
try {
  const page = await browser.newPage({ignoreHTTPSErrors:true,viewport:{width:1440,height:960}})
  page.setDefaultTimeout(20000)
  await page.addInitScript(observe)
  stage='guest'; const guest = await guestFaults(page,input)
  stage='login'
  await page.getByLabel('Логин',{exact:true}).fill('qa_admin')
  await page.getByLabel('Пароль',{exact:true}).fill(input.password)
  await page.getByRole('button',{name:'Войти',exact:true}).click()
  await expect(page.getByTestId('app-shell')).toBeVisible()
  const category = await api(page,'/admin/categories','POST',{name:'R2 Connect'}); status(category,201)
  const room = await api(page,`/admin/categories/${category.body.id}/channels`,'POST',{name:'R2 Voice',kind:'VOICE'}); status(room,201)
  await channel(page,'R2 Voice',room.body.id)
  stage='voice'; await page.getByRole('button',{name:'Без микрофона',exact:true}).click()
  await healthy(page)
  await page.screenshot({path:input.directory+'/populated.png'})
  stage='faults'; const cases = await faults(page,input)
  stage='cancellation'; const cancelled = await cancellation(page,input,room.body.id)
  await page.screenshot({path:input.directory+'/recovered.png'})
  writeFileSync(input.directory+'/scenario.json',JSON.stringify({status:'PASS',r2_faults:cases,r2_public_faults:guest,
    manual_cancel_logout_late401_server_expiry:cancelled,public_scope_unload_cancel:true,actual_api:true,actual_sfu:true}))
} catch(error) {
  console.log('R2_WEB_FAILURE',JSON.stringify(writeFailure(input.directory,stage,error)))
  process.exitCode=1
} finally { await browser.close() }
