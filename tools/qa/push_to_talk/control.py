"""Nonce-authenticated loopback stop/start of this fixture's SFU only."""
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import re
import secrets
from threading import Lock, Thread
from tools.qa.client_lifecycle.services import LABEL, output, run


@contextmanager
def media_control(stack):
    if not re.fullmatch(r'qa-client-[0-9a-f]{16}', stack.owner):
        raise ValueError('Owned namespace required')
    token, lock = secrets.token_hex(32), Lock()
    name = stack.owner+'-sfu'

    class Handler(BaseHTTPRequestHandler):
        def setup(self):
            super().setup(); self.connection.settimeout(15)

        def log_message(self, *_):
            pass

        def do_POST(self):
            if self.path not in ('/stop-sfu', '/start-sfu') or self.headers.get('Content-Length', '0') != '0':
                self.send_error(404); return
            if not secrets.compare_digest(self.headers.get('Authorization', ''), 'Bearer '+token):
                self.send_error(403); return
            with lock:
                try:
                    if ('container', name) not in stack.resources:
                        raise ValueError('Unowned SFU')
                    owner = output('docker', 'inspect', name, '--format', '{{index .Config.Labels "'+LABEL+'"}}')
                    if owner != stack.owner:
                        raise ValueError('Foreign SFU')
                    command = ('stop', '--time=0') if self.path == '/stop-sfu' else ('start',)
                    run('docker', *command, name, stdout=__import__('subprocess').DEVNULL)
                except Exception:
                    self.send_error(500, 'Owned media action failed'); return
            self.send_response(204); self.end_headers()

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    worker = Thread(target=server.serve_forever, daemon=True); worker.start()
    try:
        yield dict(base=f'http://127.0.0.1:{server.server_port}', token=token)
    finally:
        server.shutdown(); server.server_close(); worker.join(timeout=2)
