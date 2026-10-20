import { lstat, readdir, readFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import path from 'node:path'
import { releaseMetadata as windowsMetadata } from '../windows/publish.mjs'

export function requireContract(value) { if (!value) throw new Error('Native release contract, source or immutable assets differ') }
const hash=bytes=>createHash('sha256').update(bytes).digest('hex')

export async function payload(contract,directory,context) {
  requireContract(contract.source_ref===context.source_ref&&contract.source_event===context.source_event
    &&['push','workflow_dispatch'].includes(contract.source_event)
    &&/^[0-9a-f]{40}$/.test(contract.trigger_revision??'')&&contract.trigger_revision===context.trigger_revision)
  const tagged=contract.source_ref==='refs/tags/'+contract.tag
  const manualMaster=contract.source_ref==='refs/heads/master'&&contract.source_event==='workflow_dispatch'
    &&contract.trigger_revision===contract.source_revision
  requireContract(contract.release_mode==='stable'&&contract.tag_verified===true&&(tagged||manualMaster))
  requireContract(contract.schema_version===1&&contract.status==='PASS'&&contract.repository==='Egkurilov/BOOHTACORD')
  requireContract(['android','windows','macos'].includes(contract.platform)&&/^[0-9a-f]{40}$/.test(contract.source_revision))
  requireContract(contract.tag===`${contract.platform}-v${contract.identity.version}`&&/^\d+\.\d+\.\d+$/.test(contract.identity.version))
  requireContract(contract.repository===context.repository&&contract.source_revision===context.source_revision&&contract.tag===context.tag
    &&contract.execution.run_id===context.execution.run_id&&contract.execution.run_attempt===context.execution.run_attempt)
  const names=Object.keys(contract.assets).sort()
  requireContract(names.length>=3&&names.length<=12&&names.includes('artifact-manifest.json')&&names.includes('SHA256SUMS'))
  requireContract(JSON.stringify((await readdir(directory)).sort())===JSON.stringify(names))
  const assets=[]
  for(const name of names) {
    requireContract(/^[A-Za-z0-9_.-]{1,255}$/.test(name))
    const file=path.join(directory,name);const stat=await lstat(file);const expected=contract.assets[name]
    requireContract(stat.isFile()&&!stat.isSymbolicLink()&&stat.size>0&&stat.size<=95_000_000&&stat.size===expected.bytes)
    requireContract(/^[0-9a-f]{64}$/.test(expected.sha256)&&hash(await readFile(file))===expected.sha256)
    assets.push(file)
  }
  requireContract(contract.manifest_sha256===contract.assets['artifact-manifest.json'].sha256)
  const base=contract.platform==='windows'?windowsMetadata(contract.tag):{
    title:`BOOHTACORD ${contract.platform==='android'?'Android':'macOS'} ${contract.identity.version}`,
    body:contract.platform==='android'?'Signed Android APKs: choose arm64-v8a, armeabi-v7a or x86_64 for your device.':
      'Universal macOS app for Apple Silicon and Intel. Ad-hoc signed; not notarized by Apple. Verify the ZIP SHA-256 before extracting.',
  }
  const metadata={title:base.title,body:base.body+'\n\n'+[
    `Source commit: ${contract.source_revision}`,`Version/build: ${contract.identity.version}+${contract.identity.native_build}`,
    `Manifest SHA256: ${contract.manifest_sha256}`,`Measured signing status: ${contract.signing.status}`,
  ].join('\n')}
  return {assets,metadata}
}
