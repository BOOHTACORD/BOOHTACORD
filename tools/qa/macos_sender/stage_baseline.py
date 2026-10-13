"""Coordinate the existing marked Mac runner and one existing baseline viewer."""
import argparse,hashlib,json,os,subprocess,sys,time
from pathlib import Path
from .observe import owned_work
from .run import OUT,ROOT,bundle_manifest
from .candidate import codec_environment

def receipt_output(out,scope):
 if scope not in(None,'metadata-failure','metadata-slow','unsigned-release','descriptor-reverse'):raise ValueError('Bounded owned runtime receipt scope required')
 return Path(out)/scope if scope else Path(out)

def require_built_proof(work,proof,build_mode="debug"):
 if build_mode not in ("debug","release"):raise ValueError("Bounded own build mode required")
 binary=work/'flutter/build/macos/Build/Products'/build_mode.capitalize()/'BOOHTACORD.app/Contents/MacOS/BOOHTACORD'
 if proof.get('status')!='BUILT' or not binary.is_file() or hashlib.sha256(binary.read_bytes()).hexdigest()!=proof.get('artifact_sha256')or bundle_manifest(binary.parent.parent.parent)!=proof.get('app_bundle_manifest_sha256'):raise ValueError('Current executable and whole Dart app bundle proof required before measurement')

def case_plan(index):
 if index not in range(1,21):raise ValueError('Only twenty explicit local baseline/candidate cells')
 return {'resolution':720 if index in (4,13,14) else 1080,'fps':30 if index in (5,17) else 60,'static':index in (6,11)}

def owned_viewer_registered(out,index):
 if index not in range(1,21):raise ValueError('Bounded owned viewer required')
 try:
  fact=json.loads((out/f'receiver-{index}-owned-fixture.json').read_text())
  if fact.get('case')==index and fact.get('fixture_present_in_owned_DB')is True and fact.get('owned_DB_label_verified')is True:return True
 except (OSError,ValueError):pass
 for candidate in [out/f'receiver-{index}-ready.json',*(out/'previous').glob(f'*/receiver-{index}-ready.json')]:
  try:
   value=json.loads(candidate.read_text())
   if value.get('ready')is True and value.get('case')==index:return True
  except (OSError,ValueError):pass
 return False

def archive_previous(out,index):
 names=[f'receiver-{index}-ready.json',f'receiver-{index}.json',f'receiver-{index}-synthetic.png',f'stage-case-{index}.json',f'codec-negotiation-{index}.json',f'healthy-{index}.json',f'restart-{index}.json']
 present=[out/name for name in names if (out/name).exists()]
 if present:
  destination=out/'previous'/str(time.time_ns());destination.mkdir(parents=True)
  for p in present:p.rename(destination/p.name)

def stop(process):
 if process and process.poll() is None:
  process.terminate()
  try:process.wait(timeout=10)
  except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)

def main():
 p=argparse.ArgumentParser();p.add_argument('--work',required=True);p.add_argument('--indices',nargs='+',type=int,required=True);p.add_argument('--capture-counters',action='store_true');p.add_argument('--source-proof',default='baseline-build-proof.json');p.add_argument('--display',action='store_true');p.add_argument('--codec',choices=['vp8','h264']);p.add_argument('--metadata',action='store_true');p.add_argument('--functional',action='store_true');p.add_argument('--mode',choices=['motion','text'],default='motion');p.add_argument('--receipt-scope',choices=['metadata-failure','metadata-slow','unsigned-release','descriptor-reverse']);p.add_argument('--build-mode',choices=['debug','release'],default='debug');args=p.parse_args()
 if args.functional and(args.codec or args.display or args.metadata):raise ValueError('Functional acceptance is a separate non-benchmark case')
 work=owned_work(args.work)
 if Path(args.source_proof).name!=args.source_proof or not args.source_proof.endswith('.json'):raise ValueError('Bounded source proof filename required')
 proof=json.loads((OUT/args.source_proof).read_text());require_built_proof(work,proof,args.build_mode)
 destination=receipt_output(OUT,args.receipt_scope);destination.mkdir(parents=True,exist_ok=True)
 plans=[(index,case_plan(index)) for index in args.indices]
 for index,plan in plans:
  registered=owned_viewer_registered(OUT,index);archive_previous(destination,index);receiver=native=None
  receipt={'status':'RUNNING','index':index,'plan':plan,'scope':'co-hosted window prototype; 30s warmup/60s steady, not release SLO','thresholdClaims':False,'source_build_proof':args.source_proof,'build_mode':args.build_mode,'capture_counter_polling':args.capture_counters,'source_kind':'display' if args.display else 'window','requested_codec_experiment':args.codec,'source_build_proof_sha256':hashlib.sha256((OUT/args.source_proof).read_bytes()).hexdigest(),'capture_diagnostics_enabled':os.environ.get('QA_NATIVE_CAPTURE_DIAGNOSTICS')=='1' if os.environ.get('QA_NATIVE_CAPTURE_DIAGNOSTICS')in('0','1')else None,'requested_content_mode':args.mode}
  path=destination/f'stage-case-{index}.json';path.write_text(json.dumps(receipt,indent=2)+'\n')
  negotiation=work/'codec-negotiation-private.json'
  if args.codec and negotiation.exists():
   destination=OUT/'previous'/str(time.time_ns());destination.mkdir(parents=True);negotiation.rename(destination/'codec-negotiation-private.json')
  started=time.monotonic()
  try:
   env=dict(os.environ,QA_STAGE_REGISTER_CONFIRMED='1' if registered else '0',QA_STAGE_INPUT=str(work/'browser-private.json'),QA_STAGE_INDEX=str(index),QA_STAGE_OUT=str(destination),BOOHTACORD_QA_STAGE='1',BOOHTACORD_QA_RESOLUTION=str(plan['resolution']),BOOHTACORD_QA_FPS=str(plan['fps']),BOOHTACORD_QA_STATIC='1' if plan['static'] else '0',BOOHTACORD_QA_PUBLISH_SECONDS='16' if args.functional else '120' if args.metadata else '110',QA_STAGE_FUNCTIONAL='1' if args.functional else '0',QA_NATIVE_LIFECYCLE='1' if args.functional else '0',QA_NATIVE_MODE=args.mode,QA_STAGE_METADATA='1' if args.metadata or args.functional else '0',BOOHTACORD_QA_CAPTURE_COUNTERS='1' if args.capture_counters else '0')
   with (work/f'stage-receiver-{index}-private.log').open('w') as log:
    receiver=subprocess.Popen(['node',str(Path(__file__).with_name('stage_receiver.mjs'))],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
    ready=destination/f'receiver-{index}-ready.json'
    deadline=time.monotonic()+35
    while not ready.exists():
     if receiver.poll() is not None:raise RuntimeError('Owned viewer exited before fresh readiness')
     if time.monotonic()>deadline:raise TimeoutError('Owned viewer readiness timeout')
     time.sleep(.25)
    if json.loads(ready.read_text()).get('case')!=index:raise RuntimeError('Wrong readiness generation')
    receipt['receiver_ready_to_producer_launch_ms']=(time.monotonic()-started)*1000
    if args.display:env['BOOHTACORD_QA_DISPLAY']='1'
    if args.codec:
     env.update(QA_NATIVE_CODEC=args.codec,QA_NATIVE_CODEC_PHASE_ADMITTED='1',QA_NATIVE_CODEC_CAPS_FILE=str(work/'codec-receivers-private.json'));env.update(codec_environment(work));receipt['codec_caps_transport']='validated owned canonical0600 capabilities via bounded env/SHA, sandbox unchanged'
    native_mode='restart' if args.functional else 'healthy'
    if args.functional:receipt['scope']='Actual native compatible update/restart/lease rejoin with current production metadata parser and fresh decoded output; no steady FPS measurement'
    native=subprocess.Popen([sys.executable,'-m','tools.qa.macos_sender.observe','--work',str(work),'--mode',native_mode,'--index',str(index),'--build-mode',args.build_mode,*(['--receipt-scope',args.receipt_scope]if args.receipt_scope else[])],cwd=ROOT,env=env)
    native_code=native.wait(timeout=185);receiver_code=receiver.wait(timeout=30)
    native_result=json.loads((destination/f'{native_mode}-{index}.json').read_text());receiver_result=json.loads((destination/f'receiver-{index}.json').read_text())
    if native_code or receiver_code or native_result.get('status')!='PASS' or receiver_result.get('status')!='PASS':raise RuntimeError('Current native/viewer flow incomplete')
    receipt.update(status='PASS',flow_only=True,native_receipt=f'{native_mode}-{index}.json',receiver_receipt=f'receiver-{index}.json',clock_alignment='Separate monotonic windows; no cross-clock glass-to-glass subtraction')
  except BaseException as error:receipt.update(status='FAIL',error_type=type(error).__name__);raise
  finally:
   stop(native);stop(receiver)
   negotiation=work/'codec-negotiation-private.json'
   if args.codec and negotiation.is_file():
    import shutil
    target=OUT/f'codec-negotiation-{index}.json';shutil.copy2(negotiation,target);receipt['codec_negotiation_receipt']=target.name;receipt['codec_negotiation_sha256']=hashlib.sha256(target.read_bytes()).hexdigest()
   receipt.update(elapsed_seconds=time.monotonic()-started,owned_processes_exited=all(q is None or q.poll() is not None for q in (native,receiver)));path.write_text(json.dumps(receipt,indent=2)+'\n')
  print(f'Local stage baseline {index}: PASS flow only',flush=True)
if __name__=='__main__':main()
