"""Authenticated loopback control of the already-owned API fixture only."""
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import re
import secrets
from threading import Lock, Thread


@contextmanager
def api_control(stack):
    if not re.fullmatch(r'qa-client-[0-9a-f]{16}', stack.owner):
        raise ValueError('Owned QA namespace required')
    token, lock = secrets.token_hex(32), Lock()

    class Handler(BaseHTTPRequestHandler):
        def setup(self):
            super().setup()
            self.connection.settimeout(10)

        def log_message(self, *_):
            pass

        def do_POST(self):
            if self.path != '/restart' or self.headers.get('Content-Length', '0') != '0':
                self.send_error(404)
                return
            if not secrets.compare_digest(self.headers.get('Authorization', ''), 'Bearer ' + token):
                self.send_error(403)
                return
            with lock:
                try:
                    stack.restart()
                except Exception:
                    self.send_error(500, 'Owned fixture restart failed')
                    return
            self.send_response(204)
            self.end_headers()

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    server.daemon_threads = False
    worker = Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        yield dict(url=f'http://127.0.0.1:{server.server_port}/restart', token=token)
    finally:
        server.shutdown()
        server.server_close()
        worker.join(timeout=2)
