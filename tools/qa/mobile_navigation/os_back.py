"""Owned emulator OS Back input; not a physical-device acceptance claim."""
import secrets
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class AndroidBackBridge:
    def __init__(self, device):
        self.device=device
        self.key=secrets.token_urlsafe(24)
        self.count=0

    def __enter__(self):
        avd=subprocess.check_output(['adb','-s',self.device,'emu','avd','name'],text=True).splitlines()[0]
        if self.device!='emulator-5556' or avd!='BOOHTACORD_QA_283_API35':
            raise ValueError('OS Back input requires the assigned owned emulator')
        owner=self
        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                if self.path!='/android-back' or self.headers.get('X-QA-Control')!=owner.key:
                    self.send_error(403);return
                result=subprocess.run(['adb','-s',owner.device,'shell','input','keyevent','KEYCODE_BACK'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                if result.returncode: self.send_error(500);return
                owner.count+=1
                self.send_response(204);self.end_headers()
            def log_message(self,*args): pass
        self.server=ThreadingHTTPServer(('127.0.0.1',4844),Handler)
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True)
        self.thread.start()
        return self

    def __exit__(self,*args):
        self.server.shutdown();self.server.server_close();self.thread.join()
