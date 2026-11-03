import { createHash } from 'node:crypto'
import { readdir, readFile, lstat } from 'node:fs/promises'
import path from 'node:path'

const require = value => { if (!value) throw new Error('SDK publication source, input, immutable assets or readback differs') }
const hash = bytes => createHash('sha256').update(bytes).digest('hex')

export async function publishSdk({github,context,execution,authorized,contract,directory}) {
  require(authorized==='true'&&context.eventName==='workflow_dispatch'&&context.ref==='refs/heads/master'
    &&`${context.repo.owner}/${context.repo.repo}`==='BOOHTACORD/BOOHTACORD')
  require(contract.status==='PASS'&&contract.schema_version===1&&contract.repository==='BOOHTACORD/BOOHTACORD'
    &&contract.builder_revision===context.sha&&/^[0-9a-f]{40}$/.test(context.sha)
    &&contract.run_id===execution.run_id&&contract.run_attempt===execution.run_attempt
    &&/^webrtc-m150-boohtacord-r[1-9][0-9]*$/.test(contract.version)&&contract.physical_playback_smoke==='NOT_RUN')
  const names=['SHA256SUMS','WebRTC-macos.xcframework.zip','sdk-manifest.json']
  require(JSON.stringify((await readdir(directory)).sort())===JSON.stringify(names)&&JSON.stringify(Object.keys(contract.assets).sort())===JSON.stringify(names))
  const files=[]
  for (const name of names) {
    const file=path.join(directory,name),stat=await lstat(file),expected=contract.assets[name]
    require(stat.isFile()&&!stat.isSymbolicLink()&&stat.size>0&&stat.size<=95_000_000&&stat.size===expected.bytes)
    const data=await readFile(file);require(hash(data)===expected.sha256);files.push({name,data})
  }
  const base={owner:context.repo.owner,repo:context.repo.repo},tag=contract.version
  try { await github.rest.repos.getReleaseByTag({...base,tag});throw new Error('SDK version already exists; immutable assets cannot be replaced') }
  catch(error) { if(error.status!==404)throw error }
  const {data:release}=await github.rest.repos.createRelease({...base,tag_name:tag,target_commitish:context.sha,
    name:`BOOHTACORD patched macOS WebRTC ${tag}`,draft:true,prerelease:false,make_latest:'false',
    body:`Source: ${context.sha}\nRecipe SHA256: ${contract.recipe_sha256}\nRun: ${execution.run_id}/${execution.run_attempt}\nAd-hoc framework; not notarized. Physical playback acceptance NOT_RUN (#335).`})
  require(release.draft===true&&release.tag_name===tag&&release.target_commitish===context.sha)
  for(const {name,data} of files) {
    await github.rest.repos.uploadReleaseAsset({...base,release_id:release.id,name,data,headers:{'content-type':'application/octet-stream','content-length':data.length}})
  }
  async function verify() {
    const {data:rows}=await github.rest.repos.listReleaseAssets({...base,release_id:release.id,per_page:50})
    require(rows.length===names.length&&new Set(rows.map(row=>row.name)).size===names.length)
    for(const row of rows)require(names.includes(row.name)&&row.size===contract.assets[row.name].bytes&&row.digest==='sha256:'+contract.assets[row.name].sha256)
    const {data:ref}=await github.rest.git.getRef({...base,ref:'tags/'+tag})
    require(ref.object.type==='commit'&&ref.object.sha===context.sha)
  }
  await verify()
  const {data:published}=await github.rest.repos.updateRelease({...base,release_id:release.id,draft:false,make_latest:'false'})
  require(published.draft===false&&published.tag_name===tag&&published.target_commitish===context.sha)
  await verify();return {status:'PASS',builder_revision:context.sha,...execution,release_id:release.id,version:tag,
    recipe_sha256:contract.recipe_sha256,manifest_sha256:contract.assets['sdk-manifest.json'].sha256,physical_playback_smoke:'NOT_RUN'}
}
