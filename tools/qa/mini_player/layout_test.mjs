// Focused CSS regression only. This does not stand in for media acceptance.
import assert from 'node:assert/strict'
import {readdirSync,readFileSync} from 'node:fs'
import {chromium,expect} from '../client_lifecycle/request.mjs'
const assets=new URL('../../../.out/qa247-build/assets/',import.meta.url)
const css=readdirSync(assets).filter(n=>n.endsWith('.css')).map(n=>readFileSync(new URL(n,assets),'utf8')).join('\n')
const browser=await chromium.launch()
try {
 for(const width of [1440,393,320]) {
  const page=await browser.newPage({viewport:{width,height:900}})
  await page.setContent(`<section class="voice-room voice-room--mini"><header class="main-header">Voice</header><section class="screen-viewer stream-wrap" aria-label="Демонстрация экрана"><div class="screen-mini-toolbar"><strong>Источник проверки</strong><div class="screen-mini-actions"><button>Пауза</button><button>Звук</button><button>Открепить</button><button>Развернуть</button><button>Закрыть</button></div></div><div class="screen-stage"><video class="screen-player"></video></div><audio></audio><div class="stream-quality-row">Full controls</div><section class="screen-rail-section">Full rail</section></section><div class="room-wrap">Voice controls</div></section>`)
  await page.addStyleTag({content:css})
  const mini=page.locator('.voice-room--mini'),toolbar=mini.locator('.screen-mini-toolbar'),stage=mini.locator('.screen-stage')
  const box=await mini.boundingBox(),video=await stage.boundingBox();assert.ok(box&&video)
  assert.ok(Math.abs(video.width/video.height-16/9)<.05,'Mini video must retain its 16:9 viewport')
  assert.ok(box.height<=160,'Reserved mini dock must remain compact')
  for(const button of await toolbar.getByRole('button').all()) {
   await expect(button).toBeVisible();const b=await button.boundingBox();assert.ok(b&&b.y>=box.y&&b.y+b.height<=box.y+box.height,'All mini controls must remain inside its unclipped surface')
   await button.focus();await expect(button).toBeFocused()
  }
  assert.ok(box.x>=0&&box.x+box.width<=width+1,'Mini must fit viewport')
  await page.close()
 }
 console.log('#247 mini CSS regression PASS at 1440/393/320')
} finally {await browser.close()}
