"""Launch only the marked Debug QA app and aggregate content-free measurements."""
import argparse,hashlib,json,os,platform,re,subprocess,time
from pathlib import Path
from .run import OUT
from .policy import cleanup,observation_poll_count
from .process_resources import read_resources
from .codec_diagnostics import parse_codec_diagnostics
from .fault_acceptance import recovery_due,require_metadata_recovery
DOMAIN='ru.boohtacord.localqa'

def owned_work(value):
 path=Path(value).resolve()
 if path.parent!=OUT.resolve() or not (path/'.qa98325-owned').is_file():raise ValueError('Marked own QA work required')
 return path

def preference():
 result=subprocess.run(['defaults','read',DOMAIN,'flutter.qa98325_state'],capture_output=True,text=True)
 if result.returncode:return None
 try:return json.loads(result.stdout)
 except ValueError:return None

def control(value):subprocess.run(['defaults','write',DOMAIN,'flutter.qa98325_control','-string',value],check=True,stdout=subprocess.DEVNULL)

def docker_owned(owner,action):
 label=subprocess.check_output(['docker','inspect',owner+'-api','--format','{{index .Config.Labels "boohtacord.qa.owner"}}'],text=True).strip()
 if not re.fullmatch('qa98325-[a-f0-9]{16}',owner) or label!=owner:raise ValueError('Refusing foreign API fault')
 subprocess.run(['docker',action,owner+'-api'],check=True,stdout=subprocess.DEVNULL)

def execute(args,destination):
 work=owned_work(args.work);config=json.loads((work/'configuration.json').read_text());owner=config['owner'];os.environ['DOCKER_CONTEXT']='colima-boohtacord-qa'
 if not 0<=args.index<=20 or not 0<=args.hold<=300:raise ValueError('Bounded case index/hold required')
 artifact=work/'flutter/build/macos/Build/Products'/args.build_mode.capitalize()/'BOOHTACORD.app';binary=artifact/'Contents/MacOS/BOOHTACORD'
 if not binary.is_file():raise RuntimeError('Built own Debug artifact required')
 report={'status':'RUNNING','case':args.mode,'index':args.index,'physical_macOS':True,'build_mode':args.build_mode,'mock_storage':False,'native_storage_scope':'unique owned accountName only; actual installed legacy Keychain plugin','artifact_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'host_context':{'logical_CPUs':os.cpu_count(),'load_average_at_launch':os.getloadavg(),'macOS_version':platform.mac_ver()[0],'other_QA_work':'coordinated parallel QA; not asserted idle'},'poll_interval_ms':250}
 destination.write_text(json.dumps(report,indent=2)+'\n')
 subprocess.run(['defaults','delete',DOMAIN,'flutter.qa98325_state'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 control('WAIT')
 start=time.monotonic();fault=None;fault_until=None;process=None;resource_rows=[];next_resource=0.0
 try:
  with (work/f'{args.mode}-{args.index}-private.log').open('w') as log:
   process=subprocess.Popen([str(binary)],env=dict(os.environ,BOOHTACORD_QA_MODE=args.mode,BOOHTACORD_QA_INDEX=str(args.index)),stdout=log,stderr=subprocess.STDOUT)
   for _ in range(observation_poll_count(os.environ.get('QA_NATIVE_RECEIVER')=='1')):
    now=time.monotonic();state=preference()
    if now>=next_resource and len(resource_rows)<180:
     resource=read_resources(process.pid)
     if resource is not None:resource_rows.append({'elapsed_monotonic_ms':(now-start)*1000,**resource})
     next_resource=now+1
    if fault_until is not None and now>=fault_until:
     docker_owned(owner,'unpause' if fault=='pause_api' else 'start');report['fault_duration_ms']=(now-fault_started)*1000;fault=None;fault_until=None
    if state and state.get('mode')==args.mode and state.get('index')==args.index:
     report['observed_native']=state
     phase=state.get('phase')
     if phase in ('pause_api','stop_api') and fault is None and 'fault_kind' not in report:
      docker_owned(owner,'pause' if phase=='pause_api' else 'stop');fault=phase;fault_started=now;fault_until=now+(20 if phase=='pause_api' else 6);report['fault_kind']=phase;control(f'{args.index}:continue')
     if os.environ.get('QA_METADATA_ISOLATED_FAULT')=='1':
      if phase=='enable_metadata_fault'and not report.get('isolated_fault_enabled'):
       subprocess.run([os.sys.executable,'-m','tools.qa.macos_sender.metadata_fault','--work',str(work),'--action','enable'],check=True);report['isolated_fault_enabled']=True;control(f'{args.index}:continue')
      if report.get('isolated_fault_enabled')and not report.get('isolated_fault_recovered')and recovery_due(state.get('events',[])):
       subprocess.run([os.sys.executable,'-m','tools.qa.macos_sender.metadata_fault','--work',str(work),'--action','recover'],check=True);report['isolated_fault_recovered']=True;report['proxy_restarted_during_recovery']=False
     if state.get('status')=='DONE':
      report.update(status='FAIL' if phase=='failed' else 'PASS',process_to_observed_completion_ms=(now-start)*1000,host_load_at_completion=os.getloadavg());destination.write_text(json.dumps(report,indent=2)+'\n');print(f'{args.mode} {args.index}: {report["status"]}',flush=True)
      if os.environ.get('QA_METADATA_ISOLATED_FAULT')=='1':
       report['isolated_metadata_recovery']=require_metadata_recovery(state.get('events',[]),os.environ.get('QA_METADATA_FAULT_MODE'));destination.write_text(json.dumps(report,indent=2)+'\n')
      if args.hold:print(f'Owned GUI review hold {args.hold}s',flush=True);time.sleep(args.hold)
      break
    if process.poll() is not None:
     if args.mode=='cleanup' and state and state.get('status')=='DONE':report['status']='PASS';break
     raise RuntimeError('Owned app exited before fresh completion')
    time.sleep(.25)
   else:raise TimeoutError('Bounded native case deadline exceeded')
 finally:
  if report.get('isolated_fault_enabled')and not report.get('isolated_fault_recovered'):
   subprocess.run([os.sys.executable,'-m','tools.qa.macos_sender.metadata_fault','--work',str(work),'--action','recover'],check=True)
  if fault:docker_owned(owner,'unpause' if fault=='pause_api' else 'start')
  if process and process.poll() is None:
   process.terminate()
   try:process.wait(timeout=10)
   except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
  report['owned_process_exited']=process is not None and process.poll() is not None
  logfile=work/f'{args.mode}-{args.index}-private.log'
  report['codec_diagnostics']=parse_codec_diagnostics(logfile.read_text(errors='replace'))if logfile.is_file()and logfile.stat().st_size<=10000000 else []
  report['process_resources']={'provenance':'ps own native PID cumulative process CPU seconds and RSS, <=180 one-second samples; no GPU/thermal/system attribution','samples':resource_rows}
  if report['status']=='RUNNING':report['status']='FAIL'
  destination.write_text(json.dumps(report,indent=2)+'\n')
 if report['status']!='PASS':raise RuntimeError('Native case incomplete; sanitized receipt retained')
def main():
 p=argparse.ArgumentParser();p.add_argument('--work',required=True);p.add_argument('--mode',choices=['startup','healthy','stall','failure','restart','cleanup'],required=True);p.add_argument('--index',type=int,required=True);p.add_argument('--hold',type=int,default=0);p.add_argument('--receipt-scope',choices=['metadata-failure','metadata-slow','unsigned-release','descriptor-reverse']);p.add_argument('--build-mode',choices=['debug','release'],default='debug');args=p.parse_args()
 OUT.mkdir(parents=True,exist_ok=True)
 from .stage_baseline import receipt_output
 output=receipt_output(OUT,args.receipt_scope);output.mkdir(parents=True,exist_ok=True)
 destination=output/f'{args.mode}-{args.index}.json'
 if destination.exists():
  archive=output/'previous'/str(time.time_ns());archive.mkdir(parents=True);destination.rename(archive/destination.name)
 destination.write_text(json.dumps({'status':'RUNNING','phase':'preflight','case':args.mode,'index':args.index})+'\n')
 try:execute(args,destination)
 except BaseException as error:
  try:report=json.loads(destination.read_text())
  except (OSError,ValueError):report={}
  report.update(status='FAIL',error_type=type(error).__name__);destination.write_text(json.dumps(report,indent=2)+'\n');raise

if __name__=='__main__':main()
