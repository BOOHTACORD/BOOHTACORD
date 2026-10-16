import {readFileSync,writeFileSync} from 'node:fs'
import {chromium,expect,login,channel} from '../client_lifecycle/request.mjs'
const config=JSON.parse(readFileSync(process.env.QA_PEER_INPUT,'utf8'))
const browser=await chromium.launch({args:['--explicitly-allowed-ports=5060']}),context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:900}}),page=await context.newPage()
try{
 await login(page,config.loginName??'qa_sender_peer',config.password)
 await channel(page,'QaVoice');await page.getByRole('button',{name:'Без микрофона',exact:true}).click()
 await expect(page.locator('.voice-status').filter({hasText:/^Голос подключён$/}).first()).toBeVisible()
 writeFileSync(process.env.QA_PEER_RESULT,JSON.stringify({status:'CONNECTED',physical:false,actual_API:true,actual_SFU:true}))
 await new Promise(resolve=>{process.stdin.once('data',resolve);process.stdin.once('end',resolve)})
 await page.getByRole('button',{name:'Выйти из голосового канала',exact:true}).first().click()
 await expect(page.locator('.voice-status').filter({hasText:'Голос подключён'})).toHaveCount(0)
 writeFileSync(process.env.QA_PEER_RESULT,JSON.stringify({status:'PASS',was_connected:true,own_leave_verified:true,physical:false,actual_API:true,actual_SFU:true}))
}catch(error){writeFileSync(process.env.QA_PEER_RESULT,JSON.stringify({status:'FAIL',error_type:error.name}));throw error}
finally{await context.close();await browser.close()}
