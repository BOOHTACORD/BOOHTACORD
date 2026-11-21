import assert from 'node:assert/strict'
import {readFileSync,writeFileSync} from 'node:fs'
import {chromium,origin} from '../client_lifecycle/request.mjs'
import {setup} from './setup.mjs'
import {desktop,recovery} from './cases.mjs'
import {touch} from './touch.mjs'

assert.equal(origin,'https://localhost:4910')
const input=JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
const browser=await chromium.launch({headless:false,args:[
  '--allow-loopback-in-peer-connection','--use-fake-device-for-media-stream',
  '--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required',
  '--mute-audio','--use-file-for-fake-audio-capture='+input.signal,
]})
const result={status:'FAIL',cases:[],synthetic_microphone:true,actual_api:true,actual_sfu:true,independent_browser_contexts:true,human_audibility:'NOT_RUN'}
let stage='setup'
try{
  const h=await setup(browser,input)
  stage='desktop';await desktop(h,input,result.cases)
  stage='recovery';await recovery(h,input,result.cases)
  stage='touch';await touch(browser,h,input,result.cases)
  result.status='PASS'
}catch(error){
  result.failure={stage,type:error.constructor.name}
  console.log('PTT_FAILURE',stage,error.constructor.name)
  const page=browser.contexts()[0]?.pages()[0]
  await page?.screenshot({path:input.directory+'/failure.png'}).catch(()=>undefined)
  process.exitCode=1
}finally{
  await browser.close()
  writeFileSync(input.directory+'/scenario.json',JSON.stringify(result,null,2)+'\n')
}
