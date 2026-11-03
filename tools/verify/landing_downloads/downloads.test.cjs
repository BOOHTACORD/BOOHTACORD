const {readFileSync}=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const {resolve}=require('node:path');
const root=process.env.BOOHTACORD_PORTAL_TEST_ROOT||resolve(__dirname,'../../..');
// Public releases are source-bound independently of the next build contract.
const published={windows:'1.0.47',macos:'1.0.45',android:'1.0.45'};
const fallback=published.windows;
const parts=fallback.split('.').map(Number);parts[2]++;const newer=parts.join('.');
const html=readFileSync(process.argv[2]||resolve(root,'index.html'),'utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const repo='https://github.com/BOOHTACORD/BOOHTACORD/releases/';
async function run(online, advertised=newer) {
 const nodes=new Map();
 for(const m of html.matchAll(/<a\b([^>]+)>/g)) {
  const attrs=Object.fromEntries([...m[1].matchAll(/([\w-]+)="([^"]*)"/g)].map(x=>[x[1],x[2]]));
  const node={...attrs,href:attrs.href,classList:{add(){}}};
  for(const k of ['id','data-download','data-direct-download','data-release'])if(attrs[k])nodes.set(k+':'+attrs[k],node);
 }
 for(const id of ['hero-download-text','year'])nodes.set('id:'+id,{textContent:''});
 const query=s=>{const m=s.match(/^\[([^=]+)="([^"]+)"\]$/);return m?nodes.get(m[1]+':'+m[2]):null;};
 const filename='BOOHTACORD-windows-v'+advertised+'-x64.zip';
 const releases=[{tag_name:'windows-v'+advertised,published_at:'2026-10-14',html_url:repo+'tag/windows-v'+advertised,assets:[{name:filename,browser_download_url:repo+'download/windows-v'+advertised+'/'+filename}]}];
 vm.runInNewContext(script,{navigator:{userAgent:'Windows'},document:{getElementById:id=>nodes.get('id:'+id),querySelector:query},URL,Date,fetch:async()=>({ok:online,json:async()=>releases})});
 await new Promise(resolve=>setImmediate(resolve));
 const version=online && advertised===newer?newer:fallback;
 assert.equal(nodes.get('data-download:windows').href,repo+'tag/windows-v'+version);
 assert.equal(nodes.get('id:hero-download').href,repo+'tag/windows-v'+version);
 assert.equal(nodes.get('data-direct-download:windows').href,repo+'download/windows-v'+version+'/BOOHTACORD-windows-v'+version+'-x64.zip');
 for(const platform of ['macos','android'])assert.equal(nodes.get('data-download:'+platform).href,repo+'tag/'+platform+'-v'+published[platform]);
}
(async()=>{await run(false);await run(true);await run(true,'1.0.42');console.log('PASS: offline fallback and release refresh keep primary buttons on release pages and direct files separate');})().catch(e=>{console.error(e.message);process.exitCode=1;});
