"""Own native PostgreSQL, API, HTTPS signaling proxy and LiveKit on Windows."""
import http.client
from http.cookies import SimpleCookie
import json
import os
from pathlib import Path
import secrets
import socket
import ssl
import subprocess
import sys
import time
import uuid

from tools.ci.native.process import ROOT
from .windows_tools import prepare


def startup_failure(role, code, raw):
    if role not in {'api', 'sfu', 'proxy'} or not isinstance(code, int):
        raise ValueError('Unsupported startup diagnostic')
    text = raw[-8192:].decode('utf-8', errors='replace').lower()
    reason = 'unclassified'
    if all(word in text for word in ('filesystem', 'space', 'invalid')):
        reason = 'invalid_space'
    elif 'access is denied' in text or 'permission denied' in text:
        reason = 'access_denied'
    elif 'not supported' in text or 'not implemented' in text:
        reason = 'unsupported'
    elif 'configure' in text or 'error parsing' in text:
        reason = 'configuration'
    elif 'bind' in text or 'address already in use' in text:
        reason = 'listen'
    return {'service': role, 'exit_code': code, 'reason': reason}


class Stack:
    def __init__(self, root):
        if sys.platform != 'win32':
            raise RuntimeError('Native Windows host required')
        self.root = root
        self.owner = 'qa337-' + secrets.token_hex(8)
        self.password = secrets.token_urlsafe(24)
        self.processes = []
        self.database_started = False
        self.cookie = ''

    def run(self, *args, **kwargs):
        return subprocess.run(list(map(str, args)), check=True,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **kwargs)

    def launch(self, role, executable, *args, **kwargs):
        if role not in {'api', 'sfu', 'proxy'}:
            raise ValueError('Unsupported native service')
        log = (self.root / ('private-' + role + '.log')).open('xb')
        process = subprocess.Popen([str(executable), *map(str, args)],
                                   stdout=log, stderr=subprocess.STDOUT, **kwargs)
        self.processes.append((role, process, log))
        return process

    def start(self):
        self.root.mkdir(parents=True, exist_ok=False)
        (self.root / 'owner.txt').write_text(self.owner)
        for port in (4910, 4911, 4912, 4914, 55437):
            with socket.socket() as listener:
                listener.bind(('127.0.0.1', port))
        with socket.socket(type=socket.SOCK_DGRAM) as listener:
            listener.bind(('127.0.0.1', 4915))
        self.pg, self.livekit = prepare(self.root / 'tools')
        password = self.root / 'database-password.txt'
        password.write_text(self.password)
        self.data = self.root / 'postgres-data'
        self.run(self.pg / 'initdb.exe', '-D', self.data, '-U', 'qa', '-A', 'scram-sha-256',
                 '--pwfile', password, '--encoding=UTF8', '--locale=C')
        self.run(self.pg / 'pg_ctl.exe', '-D', self.data, '-l', self.root / 'private-postgres.log',
                 '-o', '-h 127.0.0.1 -p 55437', '-w', 'start')
        self.database_started = True
        environment = dict(os.environ, PGPASSWORD=self.password)
        self.run(self.pg / 'createdb.exe', '-h', '127.0.0.1', '-p', '55437', '-U', 'qa', 'qa', env=environment)
        self.environment = dict(os.environ,
            DATABASE_URL=f'postgres://qa:{self.password}@127.0.0.1:55437/qa?sslmode=disable',
            API_ADDR='127.0.0.1:4911', PUBLIC_ORIGIN='https://localhost:4910',
            TRUSTED_PROXY_CIDRS='127.0.0.1/32',
            ATTACHMENTS_DIRECTORY=str(self.root / 'attachments'),
            LIVEKIT_API_KEY='qa-only', LIVEKIT_API_SECRET='qa-local-only-secret-12345',
            LIVEKIT_PUBLIC_WS_URL='wss://localhost:4910/qa-sfu',
            LIVEKIT_PRIVATE_HTTP_URL='http://127.0.0.1:4912',
            CLIENT_UPDATE_CATALOG_PATH=str(self.root / 'catalog.json'),
            CLIENT_UPDATE_ALLOWED_HOSTS='github.com')
        self.environment.pop('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', None)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        for name, source in (('api', './cmd/api'), ('migrate', './cmd/migrate'),
                             ('bootstrap', './cmd/bootstrap_admin')):
            self.run('go', 'build', '-o', self.bin / (name + '.exe'), source, cwd=ROOT / 'backend')
        self.run('go', 'build', '-o', self.bin / 'proxy.exe',
                 ROOT / 'tools/qa/desktop_updates/loopback_proxy/main.go', cwd=ROOT)
        self.run(self.bin / 'migrate.exe', env=self.environment)
        self.run(self.bin / 'bootstrap.exe', '--login', 'qa_admin', '--password-stdin',
                 input=self.password + '\n', text=True, env=self.environment)
        self.write_catalog(None)
        self.launch('api', self.bin / 'api.exe', env=self.environment)
        config = self.root / 'livekit.yaml'
        config.write_text('''port: 4912
bind_addresses: ["127.0.0.1"]
rtc:
  tcp_port: 4914
  udp_port: 4915
  use_external_ip: false
  enable_loopback_candidate: true
keys:
  qa-only: qa-local-only-secret-12345
webhook:
  api_key: qa-only
  urls: ["http://127.0.0.1:4911/internal/livekit/roster"]
''')
        self.launch('sfu', self.livekit, '--config', config, '--node-ip', '127.0.0.1')
        self.launch('proxy', self.bin / 'proxy.exe', '--work', self.root)
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            for role, process, log in self.processes:
                code = process.poll()
                if code is not None:
                    log.flush()
                    with Path(log.name).open('rb') as stream:
                        stream.seek(max(0, Path(log.name).stat().st_size - 8192))
                        detail = startup_failure(role, code, stream.read(8192))
                    print(json.dumps({'startup_failure': detail}), flush=True)
                    raise RuntimeError('Owned native dependency exited: ' + role)
            try:
                self.context = ssl.create_default_context(cafile=str(self.root / 'owned-root.crt'))
                if self.request('/health')[0] == 200:
                    self.seed()
                    return
            except (OSError, ssl.SSLError):
                pass
            time.sleep(.2)
        raise RuntimeError('Owned native HTTPS API did not become ready')

    def request(self, path, method='GET', body=None):
        client = http.client.HTTPSConnection('localhost', 4910, context=self.context, timeout=15)
        try:
            client.request(method, '/api/v1' + path,
                           None if body is None else json.dumps(body),
                           {'Origin': 'https://localhost:4910', 'Cookie': self.cookie,
                            'Content-Type': 'application/json'})
            response = client.getresponse()
            raw = response.read()
            return response.status, json.loads(raw) if raw else None, dict(response.getheaders())
        finally:
            client.close()

    def seed(self):
        status, _, headers = self.request('/auth/login', 'POST',
                                         {'login': 'qa_admin', 'password': self.password})
        if status != 204:
            raise RuntimeError('Owned fixture sign-in failed')
        self.cookie = 'vp_session=' + SimpleCookie(headers['Set-Cookie'])['vp_session'].value
        status, category, _ = self.request('/admin/categories', 'POST', {'name': 'Updater acceptance'})
        if status != 201:
            raise RuntimeError('Owned category creation failed')
        self.channels = {}
        for kind in ('TEXT', 'VOICE'):
            status, channel, _ = self.request('/admin/categories/' + category['id'] + '/channels',
                'POST', {'name': 'Update ' + kind, 'kind': kind})
            if status != 201:
                raise RuntimeError('Owned channel creation failed')
            self.channels[kind] = channel['id']
        for index in range(70):
            status, _, _ = self.request('/channels/' + self.channels['TEXT'] + '/messages', 'POST',
                {'client_message_id': str(uuid.uuid4()), 'body': f'Update history row {index:02d}'})
            if status != 201:
                raise RuntimeError('Owned synthetic history creation failed')
            time.sleep(.06)
        self.request('/auth/logout', 'POST')
        self.cookie = ''

    def write_catalog(self, envelope):
        entries = []
        if envelope:
            import base64
            value = json.loads(base64.b64decode(envelope['payload']))
            entries = [{'platform': 'windows', 'distribution': 'direct', 'channel': 'beta',
                'arch': 'x64', 'state': 'published', 'target': {
                    'release_id': value['release_id'], 'release_order': value['release_order'],
                    'version': value['version'], 'native_build': value['native_build'],
                    'priority': 'normal', 'published_at': '2026-10-15T00:00:00Z',
                    'summary': 'Owned Windows updater acceptance',
                    'requirements': {'min_os_version': '10.0', 'supported_arches': ['x64']},
                    'release_notes_url': 'https://github.com/Egkurilov/BOOHTACORD/releases',
                    'action': {'kind': 'open_download_page', 'url': 'https://github.com/Egkurilov/BOOHTACORD/releases'},
                    'install_artifact': envelope}}]
        (self.root / 'catalog.json').write_text(json.dumps({
            'schema_version': 1, 'catalog_revision': 2 if envelope else 1,
            'application_family': 'boohtacord', 'entries': entries}))

    def wait_catalog(self, envelope):
        # The real API reloads files every ten seconds. A healthy API can still
        # serve revision 1 immediately after the fixture publishes revision 2.
        # Observe the actual endpoint before starting a client/check timer.
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                status, policy, _ = self.request(
                    '/client-updates?platform=windows&distribution=direct&channel=beta&arch=x64')
                if (status == 200 and isinstance(policy, dict) and
                        policy.get('catalog_revision') == 2 and
                        policy.get('state') == 'published' and
                        isinstance(policy.get('target'), dict) and
                        policy['target'].get('install_artifact') == envelope):
                    return
            except (OSError, http.client.HTTPException, json.JSONDecodeError):
                pass
            time.sleep(.2)
        raise RuntimeError('Owned signed catalog was not served before client startup')

    def private_configuration(self):
        return {'origin': 'https://localhost:4910/api/v1',
                'ca_pem': (self.root / 'owned-root.crt').read_text(),
                'namespace': 'ru.boohtacord.qa337.' + self.owner.removeprefix('qa337-'),
                'bootstrap': True, 'bootstrap_login': 'qa_admin',
                'bootstrap_password': self.password,
                'windows_acceptance': str(self.root / 'driver'),
                'text_channel': self.channels['TEXT'], 'voice_channel': self.channels['VOICE']}

    def close(self):
        if not self.root.exists() or (self.root / 'owner.txt').read_text() != self.owner:
            raise RuntimeError('Refusing foreign fixture cleanup')
        for _, process, log in reversed(self.processes):
            try:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=15)
            finally:
                log.close()
        if self.database_started:
            self.run(self.pg / 'pg_ctl.exe', '-D', self.data, '-m', 'fast', '-w', 'stop')


def main():
    root = Path(os.environ['RUNNER_TEMP']) / ('qa337-' + secrets.token_hex(8))
    stack = Stack(root)
    try:
        stack.start()
        client = http.client.HTTPSConnection('localhost', 4910, context=stack.context, timeout=10)
        try:
            client.request('GET', '/qa-sfu/')
            response = client.getresponse()
            response.read()
            if response.status != 200:
                raise RuntimeError('Owned SFU HTTPS signaling route is not healthy')
        finally:
            client.close()
        # An existing public owner-signed fixture also checks hot-reload readiness
        # before spending time rebuilding the two installed clients. No key or
        # executable is obtained from the service or executed by this preflight.
        envelope = json.loads((ROOT / 'evidence/fixtures/desktop-updates/'
            'windows-cba532a152f85972f3fb823b19719bb41318501f.json').read_text())
        status, initial, _ = stack.request(
            '/client-updates?platform=windows&distribution=direct&channel=beta&arch=x64')
        if (status != 200 or initial.get('catalog_revision') != 1 or
                initial.get('state') != 'unconfigured'):
            raise RuntimeError('Owned initial catalog was not served')
        started = time.monotonic()
        stack.write_catalog(envelope)
        stack.wait_catalog(envelope)
        print(json.dumps({'catalog_readiness': {'initial_revision': 1,
            'served_revision': 2, 'wait_ms': int((time.monotonic() - started) * 1000)}}), flush=True)
        print('PASS: native PostgreSQL, API, TLS/SFU, history and served signed catalog', flush=True)
    finally:
        if root.exists():
            stack.close()


if __name__ == '__main__':
    main()
