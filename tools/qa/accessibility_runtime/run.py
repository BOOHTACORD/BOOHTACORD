"""Own actual stack for accessibility traversal; no mocked app or API."""
from pathlib import Path
import hashlib,json,os,subprocess,tempfile,time,shutil
from datetime import datetime,timezone
from tools.qa.mini_player.native import source_manifest,archive_previous
from .stack import Stack

REQUIRED_WEB = ('guild_keyboard_trap_escape_restore','chat_dm_keyboard_route','seven_admin_sections_keyboard_names_state','settings_keyboard_tabs','dialog_cancel_first_cycle_escape_restore','voice_prejoin_named_controls','stream_setup_keyboard_names','guild_voice_dock_keyboard_names')
AXE_WEB = ('guild_navigation','chat','dm','admin_Гильдия','admin_Участники','admin_Роли','admin_Каналы','admin_Аудит','admin_Медиа','admin_Готовность','settings','dialogs','voice_prejoin','stream_setup','chat_2x','guild_navigation_voice_connected')

def validated_web(scenario):
 checks=scenario.get('checks',{})
 if scenario.get('status') not in ('PASS','PARTIAL') or any(checks.get(k)!='PASS' for k in REQUIRED_WEB) or any(checks.get('axe_'+k)!='PASS' for k in AXE_WEB):raise RuntimeError('Required actual Web accessibility checks incomplete')
 if scenario.get('actual_api') is not True or scenario.get('actual_sfu') is not True or scenario.get('mocks') is not False:raise RuntimeError('Actual Web transport provenance missing')
 return dict(scenario,status='PARTIAL')

def validated_active_geometry(scenario):
 names={f'{kind}-{width}-{scale}x' for width in (393,320) for scale in (1,2) for kind in ('voice-TEXT','voice-DM','members','search','search-scope')}
 rows={r['name']:r.get('status') for r in scenario.get('rows',[])}
 if scenario.get('status')!='PASS' or any(rows.get(n)!='PASS' for n in names) or scenario.get('actual_api') is not True or scenario.get('actual_sfu') is not True or scenario.get('mocks') is not False:raise RuntimeError('Actual connected mobile geometry incomplete')
 return scenario

def validated_build_provenance(source,binary):
 if source.get('status')!='PASS' or source.get('source_stable_during_unit_and_build') is not True or source.get('built_dist_manifest_sha256')!=binary or not source.get('web_src_manifest_sha256'):raise RuntimeError('Copied binary does not match frozen root build provenance')
 return source

def main():
 root=Path(__file__).resolve().parents[3];out=root/'.out/qa301-20261012/web';out.mkdir(parents=True,exist_ok=True);archive_previous(out)
 report={'issue':301,'status':'RUNNING','runtime_completed':False,'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'started_at':datetime.now(timezone.utc).isoformat(),'observed_workingtree_source_manifest':source_manifest(root/'clients/web/src')[0]}
 receipt=out/'runtime.json';receipt.write_text(json.dumps(report,indent=2)+'\n');os.environ['DOCKER_CONTEXT']='colima-boohtacord-qa'
 try:
  build=root/'.out/qa301-build';shutil.rmtree(build,ignore_errors=True);shutil.copytree(root/'clients/web/dist',build,dirs_exist_ok=True);report['build_manifest']=source_manifest(build)[0]
  provenance=root/'.out/qa302-20261012/final-build-source.json';report['binary_source_provenance']=validated_build_provenance(json.loads(provenance.read_text()),report['build_manifest']);report['binary_source_provenance_sha256']=hashlib.sha256(provenance.read_bytes()).hexdigest();report['binary_source_provenance_path']=str(provenance.relative_to(root))
 except Exception as e:
  report.update(status='FAIL',error_phase='build provenance',error_type=type(e).__name__,completed_at=datetime.now(timezone.utc).isoformat());receipt.write_text(json.dumps(report,indent=2)+'\n');raise
 report['qa_handler_sha256']={n:hashlib.sha256((root/'tools/qa/accessibility_runtime'/n).read_bytes()).hexdigest() for n in ('run.py','stack.py','scenario.mjs','text_scale.mjs','active_voice_scale.mjs')}
 if os.environ.get('QA_EXISTING_FIXTURE')=='1':
  (out/'text-scale.json').unlink(missing_ok=True)
  inputs=Path((out.parent/'active-input-path').read_text())
  if json.loads((out.parent/'fixture-runtime.json').read_text()).get('status')!='READY':raise RuntimeError('Owned fixture not READY')
  report['phase']='actual browser on owned existing fixture';receipt.write_text(json.dumps(report,indent=2)+'\n')
  try:
   subprocess.run(['node',str(root/'tools/qa/accessibility_runtime/text_scale.mjs')],cwd=root,env=dict(os.environ,QA_ORIGIN='https://localhost:4930',QA_SCALE_RESULT=str(out/'text-scale.json'),QA_SOURCE_CSS='0'),check=True,timeout=180)
   report['text_scale_geometry']=json.loads((out/'text-scale.json').read_text())
   (out/'active-voice.json').unlink(missing_ok=True)
   subprocess.run(['node',str(root/'tools/qa/accessibility_runtime/active_voice_scale.mjs')],cwd=root,env=dict(os.environ,QA_ORIGIN='https://localhost:4930',QA_INPUT=str(inputs),QA_RESULT=str(out/'active-voice.json'),QA_EXTRA_CSS=''),check=True,timeout=180)
   report['connected_voice_geometry']=validated_active_geometry(json.loads((out/'active-voice.json').read_text()))
   subprocess.run(['node',str(root/'tools/qa/accessibility_runtime/scenario.mjs')],cwd=root,env=dict(os.environ,QA_ORIGIN='https://localhost:4930',QA_INPUT=str(inputs),QA_RESULT=str(out/'scenario.json')),check=True,timeout=900)
   report.update(validated_web(json.loads((out/'scenario.json').read_text())));report['runtime_completed']=True
  except Exception as e:report.update(status='FAIL',error_type=type(e).__name__);raise
  finally:
   report.update(owned_resources_removed=False,fixture_cleanup_owner='serve.py',completed_at=datetime.now(timezone.utc).isoformat(),screenshots={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')});receipt.write_text(json.dumps(report,indent=2)+'\n')
  if report.get('status') not in ('PASS','PARTIAL'):raise RuntimeError('Browser scenario failed')
  return
 with tempfile.TemporaryDirectory(prefix='qa301-',dir=root/'.out') as temp:
  stack=Stack(root,Path(temp))
  try:
   stack.start();inputs=Path(temp)/'input.json';inputs.write_text(json.dumps({'password':stack.password,'directory':str(out),'owner':stack.owner}));inputs.chmod(0o600)
   (out.parent/'active-input-path').write_text(str(inputs));report['phase']='actual browser';receipt.write_text(json.dumps(report,indent=2)+'\n')
   subprocess.run(['node',str(root/'tools/qa/accessibility_runtime/scenario.mjs')],cwd=root,env=dict(os.environ,QA_ORIGIN='https://localhost:4930',QA_INPUT=str(inputs),QA_RESULT=str(out/'scenario.json')),check=True,timeout=900)
   report['runtime_completed']=True
   outcome=validated_web(json.loads((out/'scenario.json').read_text()));report.update(outcome);receipt.write_text(json.dumps(report,indent=2)+'\n')
   if os.environ.get('QA_HOLD_FOR_NATIVE')=='1':
    print('QA301 browser completed; own stack available for native',flush=True)
    while not Path('/private/tmp/qa301-release').exists():time.sleep(.5)
  except Exception as e:report.update(status='FAIL',error_type=type(e).__name__);raise
  finally:
   stack.close();(out.parent/'active-input-path').unlink(missing_ok=True);report['owned_resources_removed']=True;report['completed_at']=datetime.now(timezone.utc).isoformat();report['screenshots']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')};receipt.write_text(json.dumps(report,indent=2)+'\n')
 if report.get('status') not in ('PASS','PARTIAL'):raise RuntimeError('Browser scenario failed')

if __name__=='__main__':main()
