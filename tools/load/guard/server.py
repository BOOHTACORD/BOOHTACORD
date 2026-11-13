"""Authenticated local guard, with restoration independent of workload health."""
import hmac
import json
import subprocess
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from .faults import Faults
from .metrics import snapshot
from .maintenance import FixtureMaintenance
from .ownership import owned, verify_marker
from .resources import Resources
from .sample_failure import SampleFailure, checked_inputs


class Guard:
    def __init__(self, stack, manifest):
        self.stack, self.manifest = stack, manifest
        verify_marker(stack, manifest['Nonce'], len(manifest['Accounts']))
        self.resources, self.faults = Resources(stack), Faults(stack)
        self.maintenance = FixtureMaintenance(stack, manifest)
        parent = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def authorized(self):
                return hmac.compare_digest(self.headers.get('X-Load-Nonce', ''), manifest['Nonce'])

            def do_GET(self):
                if not self.authorized():
                    self.send_error(403)
                    return
                if self.path.startswith('/fault-status/'):
                    try:
                        active = parent.faults.active(self.path.removeprefix('/fault-status/'))
                        self.send_response(204 if active else 409)
                        self.end_headers()
                    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
                        self.send_error(503)
                    return
                if self.path != '/snapshot':
                    self.send_error(404)
                    return
                try:
                    data = parent.sample()
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps(data).encode())
                except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                    return
                except SampleFailure as failure:
                    self.send_response(503)
                    self.send_header('X-QA-Guard-Stage', str(failure))
                    self.end_headers()
                except (OSError, ValueError, RuntimeError):
                    try:
                        self.send_error(503)
                    except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                        return

            def do_POST(self):
                if not self.authorized():
                    self.send_error(403)
                    return
                try:
                    if self.path == '/maintenance/on':
                        parent.maintenance.activate()
                        self.send_response(204)
                        self.end_headers()
                        return
                    if not self.path.startswith('/fault/'):
                        raise ValueError('Unknown controller command')
                    seconds = self.headers.get('X-QA-Fault-Seconds', '2')
                    if not seconds.isascii() or not seconds.isdecimal() or not 1 <= int(seconds) <= 30:
                        raise ValueError('Invalid bounded fault duration')
                    owned(stack, 'db')  # Recovery checks ownership, never a health threshold.
                    parent.faults.apply(self.path.removeprefix('/fault/'), seconds=int(seconds))
                    self.send_response(204)
                    self.end_headers()
                except (OSError, ValueError, RuntimeError):
                    self.send_error(503)

        self.server = ThreadingHTTPServer(('127.0.0.1', 4890), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    def sample(self):
        data = checked_inputs(self.stack, self.manifest, self.resources, verify_marker)
        data.update(Owner=self.manifest['Owner'], Dataset='qa', Origin=self.manifest['Origin'],
                    Commit=self.manifest['Commit'], DBName='qa', Accounts=len(self.manifest['Accounts'])+1,
                    At=datetime.now(timezone.utc).isoformat())
        if self.faults.sfu_outage_active():
            data.update(Metrics={}, MetricsStatus='UNAVAILABLE')
            return data
        try:
            data.update(Metrics=snapshot(), MetricsStatus='AVAILABLE')
        except OSError:
            data.update(Metrics={}, MetricsStatus='UNAVAILABLE')
        return data

    def start(self):
        self.thread.start()

    def close(self):
        try:
            self.faults.restore()
        finally:
            try:
                self.maintenance.restore()
            finally:
                if self.thread.is_alive():
                    self.server.shutdown()
                self.server.server_close()
                self.thread.join(timeout=3) if self.thread.is_alive() else None
