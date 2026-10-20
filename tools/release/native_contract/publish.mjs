import { readFile, writeFile } from 'node:fs/promises'
import { execFileSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { publishContract } from './publisher.mjs'
import { requireContract as require } from './payload.mjs'

async function main() {
  if(!process.env.GITHUB_TOKEN)throw new Error('GITHUB_TOKEN is required')
  const args=process.argv.slice(2)
  require(args.length===2&&args[0]==='--platform'&&['android','windows','macos'].includes(args[1]))
  const platform=args[1];const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..')
  require(process.env.GITHUB_ACTIONS==='true')
  const source=execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim()
  const receipt=path.join(root,'.out/native-release',platform,'publication.json')
  await writeFile(receipt,JSON.stringify({status:'FAIL',source_revision:source})+'\n')
  // Re-run complete local source/assets verification immediately before any API write.
  execFileSync(process.platform==='win32'?'python':'python3',['-m','tools.release.native_contract.run','assets',platform],{cwd:root,stdio:'inherit'})
  const contract=JSON.parse(await readFile(path.join(root,'.out/native-release',platform,'contract.json'),'utf8'))
  require(/^[0-9a-f]{40}$/.test(process.env.GITHUB_SHA??''))
  const trigger=execFileSync('git',['rev-parse',process.env.GITHUB_SHA+'^{commit}'],{cwd:root,encoding:'utf8'}).trim()
  require(source===trigger)
  const context={repository:process.env.GITHUB_REPOSITORY,source_revision:source,tag:contract.tag,
    source_ref:process.env.GITHUB_REF,source_event:process.env.GITHUB_EVENT_NAME,trigger_revision:process.env.GITHUB_SHA,
    execution:{run_id:process.env.GITHUB_RUN_ID,run_attempt:process.env.GITHUB_RUN_ATTEMPT}}
  const {release}=await publishContract({contract,context,directory:path.join(root,'clients/flutter/build/release-assets'),token:process.env.GITHUB_TOKEN})
  await writeFile(receipt,JSON.stringify({status:'PASS',source_revision:source,tag:contract.tag,
    release_id:release.id,manifest_sha256:contract.manifest_sha256,execution:context.execution})+'\n')
  console.log(`Verified native release ${contract.tag} at ${source}; release ID ${release.id}`)
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch(error=>{console.error(error.message);process.exitCode=1})
}
