"""Actual owned Android OS lifecycle dispatch, not physical-device acceptance."""
import secrets
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from .integrity import validate_device

class AndroidLifecycleBridge:
    def __init__(self,device):self.device=device;self.key=secrets.token_urlsafe(32);self.count=0
    def __enter__(self):
        validate_device('android',self.device);owner=self
        class Handler(BaseHTTPRequestHandler):
            def log_message(self,*args):pass
            def do_POST(self):
                if self.path!='/background-resume' or self.headers.get('X-QA-Control')!=owner.key:self.send_error(403);return
                try:
                    subprocess.run(['adb','-s',owner.device,'shell','input','keyevent','KEYCODE_HOME'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
                    time.sleep(1)
                    subprocess.run(['adb','-s',owner.device,'shell','am','start','-n','ru.boohtacord.qa294/ru.boohtacord.app.MainActivity'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
                    owner.count+=1;self.send_response(204);self.end_headers()
                except Exception:self.send_error(502,'Owned lifecycle dispatch failed')
        self.server=ThreadingHTTPServer(('127.0.0.1',4944),Handler);self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start();return self
    def __exit__(self,*args):self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
