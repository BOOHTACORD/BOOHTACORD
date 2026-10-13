"""Isolate only the marked proxy's metadata PUT failure; native TLS stays intact."""
import argparse,hashlib,json,os,re,subprocess,time
from pathlib import Path
from .observe import owned_work
from .run import OUT
from tools.qa.admin_dialogs.stack import ready
FLAG='/tmp/qa98325-metadata-fault-enabled'
def fault_config(original,owner,mode):
 if not re.fullmatch('qa98325-[a-f0-9]{16}',owner)or mode not in ('failure','slow')or 'tls internal'not in original:raise ValueError('Owned TLS metadata fault required')
 block='  handle /api/* {\n    reverse_proxy '+owner+'-api:8080\n  }'
 if original.count(block)!=1:raise ValueError('Exact original API block required')
 effect='respond 503'if mode=='failure'else 'rewrite * /cgi-bin/slow\n      reverse_proxy 127.0.0.1:8081 {\n        method POST\n        header_up -Cookie\n        header_up -Authorization\n      }'
 injected="""  handle /api/* {
    @qa_metadata_profile {
      method PUT
      path /api/v1/voice/leases/*/screen-profile/v1
      file {
        root /tmp
        try_files qa98325-metadata-fault-enabled
      }
    }
    handle @qa_metadata_profile {
      EFFECT
    }
    handle {
      reverse_proxy OWNER-api:8080
    }
  }""".replace('EFFECT',effect).replace('OWNER',owner)
 return original.replace(block,injected)
def main():
 p=argparse.ArgumentParser();p.add_argument('--work',required=True);p.add_argument('--action',choices=['failure','slow','enable','recover','restore'],required=True);args=p.parse_args();work=owned_work(args.work);config=json.loads((work/'configuration.json').read_text());owner=config['owner'];os.environ['DOCKER_CONTEXT']='colima-boohtacord-qa'
 if not re.fullmatch('qa98325-[a-f0-9]{16}',owner):raise ValueError('Owned proxy required')
 proxy=owner+'-proxy';label=subprocess.check_output(['docker','inspect',proxy,'--format','{{index .Config.Labels "boohtacord.qa.owner"}}'],text=True).strip()
 if label!=owner:raise ValueError('Foreign proxy rejected')
 original_work=next(p for p in OUT.glob('owned-*')if(p/'configuration.json').is_file()and json.loads((p/'configuration.json').read_text()).get('owner')==owner and(p/'stack/Caddyfile').is_file());caddy=original_work/'stack/Caddyfile';saved=work/'metadata-original-Caddyfile';receipt=OUT/'metadata-proxy-fault.json'
 def docker(*parts):subprocess.run(['docker','exec',proxy,*parts],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 if args.action in ('failure','slow'):
  if not saved.exists():saved.write_bytes(caddy.read_bytes())
  original=saved.read_text();assert caddy.read_bytes()==saved.read_bytes()
  report={'status':'RUNNING','mode':args.action,'original_proxy_sha256':hashlib.sha256(saved.read_bytes()).hexdigest(),'TLS':'Original exact owned CA/certificate/hostname verification unchanged','scope':'Only exact metadata PUT path returns an isolated proxy fault; other API/SFU paths retain original routing','resource_cleanup':'Owned proxy container disposal also removes its loopback fixture process'}
  receipt.write_text(json.dumps(report,indent=2)+'\n')
  if args.action=='slow':
   applets=subprocess.check_output(['docker','exec',proxy,'busybox','--list'],text=True).splitlines()
   if 'nc'not in applets:raise RuntimeError('Existing owned proxy lacks loopback fixture applet')
   fixture=work/'metadata-fault/cgi-bin';fixture.mkdir(parents=True,exist_ok=True);script=fixture/'slow';script.write_text('#!/bin/sh\nexec 0</dev/null\nsleep 14\nprintf "HTTP/1.1 503 Service Unavailable\\r\\nContent-Length: 0\\r\\nConnection: close\\r\\nCache-Control: no-store\\r\\n\\r\\n"\n');script.chmod(0o755)
  caddy.write_text(fault_config(original,owner,args.action));docker('caddy','validate','--config',str(caddy),'--adapter','caddyfile');docker('rm','-f',FLAG);subprocess.run(['docker','restart',proxy],check=True,stdout=subprocess.DEVNULL)
  if args.action=='slow':subprocess.run(['docker','exec','-d',proxy,'busybox','nc','-lk','-p','8081','-s','127.0.0.1','-e',str(script)],check=True,stdout=subprocess.DEVNULL)
  ready('https://localhost:5060/api/v1/health');report.update(status='APPLIED_BEFORE_NATIVE_RUN',fault_proxy_sha256=hashlib.sha256(caddy.read_bytes()).hexdigest(),api_health_status=200);receipt.write_text(json.dumps(report,indent=2)+'\n')
 elif args.action=='enable':
  docker('touch',FLAG);report=json.loads(receipt.read_text());report.update(fault_flag_enabled=True,proxy_restarted_for_enable=False);receipt.write_text(json.dumps(report,indent=2)+'\n')
 elif args.action=='recover':
  docker('rm','-f',FLAG);report=json.loads(receipt.read_text());report.update(recovery_flag_removed=True,proxy_restarted_for_recovery=False,recovery_observed_at_host_monotonic=time.monotonic());receipt.write_text(json.dumps(report,indent=2)+'\n');print('Owned metadata fault flag removed without proxy restart')
 else:
  assert saved.is_file();docker('rm','-f',FLAG);caddy.write_bytes(saved.read_bytes());subprocess.run(['docker','restart',proxy],check=True,stdout=subprocess.DEVNULL);ready('https://localhost:5060/api/v1/health');report=json.loads(receipt.read_text());report.update(status='RESTORED_AFTER_NATIVE_STOP',proxy_restored_sha256=hashlib.sha256(caddy.read_bytes()).hexdigest(),exact_original_restored=caddy.read_bytes()==saved.read_bytes(),api_health_status=200);receipt.write_text(json.dumps(report,indent=2)+'\n')
 print('Owned metadata fault: '+args.action)
if __name__=='__main__':main()
