import { GitHubApiError, apiUrl, isRetryable, maxAttempts, retryDelay, sendJson } from '../android/github_api.mjs'
import { uploadAssets } from '../android/upload_assets.mjs'
import { payload, requireContract as require } from './payload.mjs'

export async function publishContract({contract,directory,context,token,apiRoot='https://api.github.com',fetchImpl=fetch,
  sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms))}) {
  if(!token)throw new Error('GITHUB_TOKEN is required')
  const {assets,metadata}=await payload(contract,directory,context)
  const [owner,repo]=contract.repository.split('/')
  const base=`/repos/${owner}/${repo}`
  const request=(pathname,method='GET',body)=>sendJson({fetchImpl,token,url:apiUrl(apiRoot,pathname),method,body})
  async function tagSource() {
    let object=(await request(base+'/git/ref/tags/'+encodeURIComponent(contract.tag))).object
    for(let depth=0;object?.type==='tag'&&depth<5;depth++) {
      require(/^[0-9a-f]{40}$/.test(object.sha));object=(await request(base+'/git/tags/'+object.sha)).object
    }
    require(object?.type==='commit'&&object.sha===contract.source_revision)
  }
  function checked(release) {
    require(Number.isSafeInteger(release?.id)&&release.id>0&&release.tag_name===contract.tag
      &&release.target_commitish===contract.source_revision&&release.name===metadata.title&&release.body===metadata.body
      &&typeof release.draft==='boolean'&&release.prerelease===false)
    const upload=new URL(release.upload_url.replace(/\{.*$/,''))
    const origin=apiRoot==='https://api.github.com'?'https://uploads.github.com':new URL(apiRoot).origin
    require(upload.origin===origin&&upload.pathname===base+`/releases/${release.id}/assets`&&!upload.search&&!upload.hash)
    return release
  }
  async function findRelease() {
    try{return checked(await request(base+'/releases/tags/'+encodeURIComponent(contract.tag)))}
    catch(error){if(!(error instanceof GitHubApiError&&error.status===404))throw error}
    // The by-tag API only guarantees published releases. Recover drafts through
    // the authenticated collection instead of creating another draft on retry.
    const matches=[]
    for(let page=1;page<=10;page++) {
      const rows=await request(base+`/releases?per_page=100&page=${page}`)
      require(Array.isArray(rows)&&rows.length<=100)
      matches.push(...rows.filter(row=>row.tag_name===contract.tag))
      require(matches.length<=1)
      if(rows.length<100)return matches.length?checked(matches[0]):null
    }
    throw new Error('Native release history exceeds the bounded draft lookup')
  }
  async function remoteAssets(release,complete) {
    const rows=await request(base+`/releases/${release.id}/assets?per_page=50&page=1`)
    require(Array.isArray(rows)&&rows.length<=Object.keys(contract.assets).length)
    const seen=new Set()
    for(const row of rows) {
      const expected=contract.assets[row.name]
      require(Object.hasOwn(contract.assets,row.name)&&expected&&!seen.has(row.name)&&row.size===expected.bytes&&row.digest==='sha256:'+expected.sha256)
      seen.add(row.name)
    }
    if(complete)require(seen.size===Object.keys(contract.assets).length)
  }
  await tagSource()
  let release=await findRelease()
  for(let attempt=1;!release&&attempt<=maxAttempts;attempt++) {
    try {
      release=checked(await request(base+'/releases','POST',{tag_name:contract.tag,target_commitish:contract.source_revision,
        name:metadata.title,body:metadata.body,draft:true,prerelease:false,make_latest:'false'}))
    } catch(error) {
      release=await findRelease()
      if(!release){if(!isRetryable(error)||attempt===maxAttempts)throw error;await sleep(retryDelay(attempt))}
    }
  }
  require(release)
  await remoteAssets(release,!release.draft)
  if(!release.draft){await tagSource();return {release,uploaded:[],alreadyPublished:true}}
  const uploaded=await uploadAssets({release,assets,token,owner,repo,apiRoot,fetchImpl,sleep})
  await remoteAssets(release,true)
  await tagSource()
  // Never change bytes, title or notes on a published release. Lost PATCH
  // responses are confirmed by exact ID and complete asset hashes before retry.
  for(let attempt=1;attempt<=maxAttempts;attempt++) {
    try {release=checked(await request(base+`/releases/${release.id}`,'PATCH',{draft:false,make_latest:'true'}))}
    catch(error) {
      release=checked(await request(base+`/releases/${release.id}`))
      if(release.draft){if(!isRetryable(error)||attempt===maxAttempts)throw error;await sleep(retryDelay(attempt));continue}
    }
    require(release.draft===false)
    await remoteAssets(release,true)
    await tagSource()
    return {release,uploaded,alreadyPublished:false}
  }
  throw new Error('Native draft publication did not complete')
}
