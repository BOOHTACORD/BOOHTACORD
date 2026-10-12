"""Build an immutable production Web candidate, pinned before compilation."""
import hashlib,json,os,shutil,subprocess,tempfile
from datetime import datetime,timezone
from pathlib import Path
from .run_native import digest,manifest

def main():
 root=Path(__file__).resolve().parents[3];receipt=root/'.out/qa294-build-source.json';receipt.parent.mkdir(exist_ok=True)
 report={'status':'RUNNING','started_at':datetime.now(timezone.utc).isoformat(),'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()}
 def save():receipt.write_text(json.dumps(report,indent=2)+'\n')
 save()
 try:
  with tempfile.TemporaryDirectory(prefix='qa294-web-build-',dir='/private/tmp')as temporary:
   copy=Path(temporary)/'clients/web';copy.mkdir(parents=True)
   for name in ('src','public'):shutil.copytree(root/'clients/web'/name,copy/name)
   for name in ('package.json','package-lock.json','index.html','tsconfig.json','vite.config.ts'):shutil.copyfile(root/'clients/web'/name,copy/name)
   contracts=Path(temporary)/'contracts';contracts.mkdir();
   for name in ('client-build.json','screen-share-profile-v1.catalog.json'):shutil.copyfile(root/'contracts'/name,contracts/name)
   (copy/'node_modules').symlink_to(root/'clients/web/node_modules',target_is_directory=True)
   sources=manifest(copy/'src')
   if sources!=manifest(root/'clients/web/src'):raise ValueError('Source changed while copying candidate')
   report.update(web_source_manifest_sha256=hashlib.sha256(json.dumps(sources,sort_keys=True).encode()).hexdigest(),web_source_files=sources,build_inputs={name:digest(copy/name)for name in('package.json','package-lock.json','index.html','tsconfig.json','vite.config.ts')},public_manifest_sha256=hashlib.sha256(json.dumps(manifest(copy/'public'),sort_keys=True).encode()).hexdigest(),contract_files={p.name:digest(p)for p in contracts.iterdir()})
   save()
   subprocess.run(['npm','run','build'],cwd=copy,env=dict(os.environ,VITE_PUBLIC_ORIGIN='https://localhost:4940',SOURCE_REVISION=report['candidate']),check=True,timeout=300)
   output=root/'.out/qa294-build'
   if output.exists():shutil.rmtree(output)
   shutil.copytree(copy/'dist',output)
   report.update(status='PASS',web_dist_manifest_sha256=hashlib.sha256(json.dumps(manifest(output),sort_keys=True).encode()).hexdigest())
 except BaseException as error:report.update(status='FAIL',error_type=type(error).__name__);raise
 finally:report['completed_at']=datetime.now(timezone.utc).isoformat();save()
if __name__=='__main__':main()
