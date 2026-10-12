"""Live loopback-only QA control of the already-running real Web publisher UI."""
import json
import secrets
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class PublisherBridge:
    def __init__(self, directory, secret, port=4834, timeout=45):
        self.directory=Path(directory);self.secret=secret;self.lock=threading.Lock();self.timeout=timeout
        bridge=self
        class Handler(BaseHTTPRequestHandler):
            def log_message(self,*args):pass
            def do_POST(self):
                if self.path!='/publisher' or self.client_address[0]!='127.0.0.1' or self.headers.get('X-QA-Control')!=bridge.secret:
                    self.send_error(403);return
                try:
                    size=int(self.headers.get('Content-Length','0'))
                    if not 0<size<=256:raise ValueError('Invalid request size')
                    action=json.loads(self.rfile.read(size)).get('action')
                    value=bridge.control(action)
                    encoded=json.dumps(value).encode();self.send_response(200)
                    self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(encoded)));self.end_headers();self.wfile.write(encoded)
                except Exception:
                    self.send_error(502,'Owned publisher UI control failed')
        self.server=ThreadingHTTPServer(('127.0.0.1',port),Handler)
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True)
    def control(self,action):
        if action not in ('remove','publish'):raise ValueError('Unsupported source action')
        with self.lock:
            request=secrets.token_hex(16);command=self.directory/'publisher-command.json';ack=self.directory/'publisher-ack.json'
            pending=command.with_suffix('.pending');pending.write_text(json.dumps({'action':action,'request':request}));pending.replace(command)
            deadline=time.monotonic()+self.timeout
            while time.monotonic()<deadline:
                if ack.exists():
                    try:value=json.loads(ack.read_text())
                    except json.JSONDecodeError:
                        time.sleep(.02);continue
                    if value.get('request')==request:
                        if value.get('status')!='PASS' or value.get('actual_publisher_ui') is not True:raise RuntimeError('Actual publisher action failed')
                        return {'action':action,'actual_publisher_ui':True}
                time.sleep(.1)
            raise TimeoutError('Actual publisher action timeout')
    def __enter__(self):self.thread.start();return self
    def __exit__(self,*args):self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
