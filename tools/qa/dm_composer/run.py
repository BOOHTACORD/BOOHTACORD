"""Production Web DM/composer scenarios against disposable actual API."""
import hashlib,json,os,subprocess,tempfile
from datetime import datetime,timezone
from pathlib import Path
from .stack import Stack
from .integrity import archive_previous,validate_report
from .run_native import digest,manifest
REQUIRED=['list_empty_composer_visible','UI_send_real_history','per_conversation_drafts','search_result_original_context_draft','per_origin_query_filters_back_resize','browser_clipboard_multiline','real_server_third_admin_DM_ACL','real_server_search_scroll_back_switch']
def main():
 root=Path(__file__).resolve().parents[3];os.environ['DOCKER_CONTEXT']='colima-boohtacord-qa'
 build=json.loads((root/'.out/qa294-build-source.json').read_text())
 actual_dist=hashlib.sha256(json.dumps(manifest(root/'.out/qa294-build'),sort_keys=True).encode()).hexdigest()
 if build.get('status')!='PASS' or actual_dist!=build.get('web_dist_manifest_sha256'):raise ValueError('Immutable build source receipt missing or stale')
 for width in map(int,os.environ.get('QA_WIDTHS','393,1440').split(',')):
  if width not in(393,1440):raise ValueError('Only registered viewports')
  out=root/'.out/qa294-20261012'/str(width);out.mkdir(parents=True,exist_ok=True);archive_previous(out)
  report={'issue':294,'status':'RUNNING','width':width,'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'started_at':datetime.now(timezone.utc).isoformat(),'web_source_manifest_sha256':build['web_source_manifest_sha256'],'build_source_candidate':build['candidate'],'checkout_web_source_matches_build':manifest(root/'clients/web/src')==build['web_source_files'],'build_receipt_sha256':digest(root/'.out/qa294-build-source.json'),'web_dist_manifest_sha256':hashlib.sha256(json.dumps(manifest(root/'.out/qa294-build'),sort_keys=True).encode()).hexdigest(),'qa_source_files':{p:digest(root/'tools/qa/dm_composer'/p)for p in('scenario.mjs','run.py','stack.py','integrity.py','build.py')},'owned_resources_removed':False};stack=None
  def save():(out/'runtime.json').write_text(json.dumps(report,indent=2)+'\n')
  save()
  try:
   with tempfile.TemporaryDirectory(prefix='qa294-web-',dir=root/'.out')as temporary:
    work=Path(temporary);stack=Stack(root,work);stack.start();report.update(backend_source_manifest_sha256=stack.backend_source_manifest_sha256,backend_image_id=stack.backend_image_id);save();inputs=work/'inputs.json';inputs.write_text(json.dumps({'password':stack.password,'width':width,'directory':str(out)}));inputs.chmod(0o600)
    subprocess.run(['node',str(root/'tools/qa/dm_composer/scenario.mjs')],cwd=root,env=dict(os.environ,QA_ORIGIN='https://localhost:4940',QA_INPUT=str(inputs),QA_RESULT=str(out/'scenario.json')),check=True,timeout=420)
    report.update(validate_report(json.loads((out/'scenario.json').read_text()),REQUIRED))
  except Exception as error:
   if(out/'scenario.json').exists():report.update(json.loads((out/'scenario.json').read_text()))
   report.update(status='FAIL',runner_error_type=type(error).__name__);raise
  finally:
   if stack is not None:stack.close();report['owned_resources_removed']=True
   report.update(completed_at=datetime.now(timezone.utc).isoformat(),screenshots={p.name:digest(p)for p in out.glob('*.png')});save()
  print('#294 Web '+str(width)+' observed PASS; physical/user timing NOT_RUN',flush=True)
if __name__=='__main__':main()
