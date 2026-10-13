"""Authenticated localhost control of exact-owned faults and real peer browser UI."""
import json,re,secrets,subprocess,threading,time
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from tools.qa.mini_player.native import verify_owned_device
class RosterBridge:
 def __init__(self,directory,secret,owner,platform,port=5076,timeout=45):
  if not re.fullmatch(r'qa272-[a-f0-9]{16}',owner):raise ValueError('Foreign fixture')
  self.directory=Path(directory);self.secret=secret;self.owner=owner;self.platform=platform;self.timeout=timeout;self.lock=threading.Lock();self.observations=[];bridge=self
  class Handler(BaseHTTPRequestHandler):
   def log_message(self,*args):pass
   def do_POST(self):
    if self.path!='/roster' or self.client_address[0]!='127.0.0.1' or self.headers.get('X-QA-Control')!=bridge.secret:self.send_error(403);return
    try:
     length=int(self.headers.get('Content-Length','0'))
     if not 0<length<=256:raise ValueError('Invalid body')
     value=bridge.control(json.loads(self.rfile.read(length)).get('action'));encoded=json.dumps(value).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(encoded)));self.end_headers();self.wfile.write(encoded)
    except Exception:self.send_error(502,'Owned roster action failed')
  self.server=ThreadingHTTPServer(('127.0.0.1',port),Handler);self.thread=threading.Thread(target=self.server.serve_forever,daemon=True)
 def control(self,action):
  if action not in ('sfu_stop','sfu_start','peer_leave','peer_join','publishers_rejoin','android_background_resume','android_framebuffer_background','android_framebuffer_listener'):raise ValueError('Unsupported action')
  with self.lock:
   begin=time.monotonic()
   if action.startswith('sfu_'):
    name=self.owner+'-sfu';label=subprocess.check_output(['docker','inspect',name,'--format','{{index .Config.Labels "boohtacord.qa.owner"}}'],text=True).strip()
    if label!=self.owner:raise ValueError('Foreign SFU')
    verb='stop' if action.endswith('stop')else'start';subprocess.run(['docker',verb,name],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30)
   elif action.startswith('android_framebuffer_'):
    if self.platform!='android':raise ValueError('Android only')
    verify_owned_device('android','emulator-5558');data=subprocess.check_output(['adb','-s','emulator-5558','exec-out','screencap','-p'],timeout=10)
    if not data.startswith(b'\x89PNG\r\n\x1a\n'):raise RuntimeError('Framebuffer PNG unavailable')
    destination=self.directory.parent/'android-visual-supplement';destination.mkdir(exist_ok=True);(destination/('native-'+action.removeprefix('android_framebuffer_')+'-framebuffer.png')).write_bytes(data)
   elif action=='android_background_resume':
    if self.platform!='android':raise ValueError('Android only')
    verify_owned_device('android','emulator-5558');subprocess.run(['adb','-s','emulator-5558','shell','input','keyevent','KEYCODE_HOME'],check=True,stdout=subprocess.DEVNULL,timeout=10);time.sleep(1)
    before=subprocess.check_output(['adb','-s','emulator-5558','shell','dumpsys','activity','activities'],text=True)
    lines=[x for x in before.splitlines()if'topResumedActivity'in x];not_own=bool(lines)and not any('ru.boohtacord.app'in x for x in lines)
    subprocess.run(['adb','-s','emulator-5558','shell','am','start','-n','ru.boohtacord.app/.MainActivity'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10);time.sleep(1)
    after=subprocess.check_output(['adb','-s','emulator-5558','shell','dumpsys','activity','activities'],text=True);resumed=any('ru.boohtacord.app'in x for x in after.splitlines()if'topResumedActivity'in x)
    if not not_own or not resumed:raise RuntimeError('Owned background transition not observed')
   else:
    request=secrets.token_hex(16);p=self.directory/'control-command.json';ack=self.directory/'control-ack.json';pending=p.with_suffix('.pending');pending.write_text(json.dumps({'action':action,'request':request}));pending.replace(p);deadline=time.monotonic()+self.timeout
    while time.monotonic()<deadline:
     if ack.exists():
      try:value=json.loads(ack.read_text())
      except json.JSONDecodeError:time.sleep(.02);continue
      if value.get('request')==request:
       if value.get('status')!='PASS' or value.get('action')!=action or value.get('actual_control')is not True:raise RuntimeError('Actual browser action failed')
       break
     time.sleep(.1)
    else:raise TimeoutError('Actual browser control deadline')
   self.observations.append({'action':action,'status':'PASS','elapsed_ms':round((time.monotonic()-begin)*1000)});return{'action':action,'actual_control':True}
 def __enter__(self):self.thread.start();return self
 def __exit__(self,*args):self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
