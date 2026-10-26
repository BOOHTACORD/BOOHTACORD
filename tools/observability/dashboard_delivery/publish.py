"""Publish the existing private Traces dashboard with optimistic concurrency.

Credentials are read without terminal echo and kept in memory. The protected
capture is a dashboard definition for rollback, never a telemetry snapshot.
"""
import argparse
import base64
import copy
import getpass
import hashlib
import json
import os
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request

UID = 'boohtacord-traces'


def canonical(dashboard):
    result = copy.deepcopy(dashboard)
    for key in ('id', 'version'):
        result.pop(key, None)
    return json.dumps(result, sort_keys=True, ensure_ascii=False, separators=(',', ':'))


def payload(source, current, expected_version):
    actual = current['dashboard']
    if source.get('uid') != UID or actual.get('uid') != UID:
        raise ValueError('refusing to replace another dashboard')
    if actual['version'] != expected_version:
        raise ValueError('dashboard changed concurrently; read and review it again')
    if current['meta'].get('provisioned') or not current['meta'].get('canSave'):
        raise ValueError('use the existing provisioning owner; UI/API overwrite forbidden')
    candidate = copy.deepcopy(source)
    candidate.update(id=actual['id'], version=expected_version)
    return {'dashboard': candidate, 'folderUid': current['meta'].get('folderUid', ''),
            'overwrite': False, 'message': 'BOOHTACORD #513 version-controlled observability'}


class Grafana:
    def __init__(self, origin, username, password):
        url = urllib.parse.urlsplit(origin)
        if url.scheme != 'https' or not url.hostname or url.username or url.path not in ('', '/') or url.query or url.fragment:
            raise ValueError('verified HTTPS Grafana origin required')
        self.origin = origin.rstrip('/')
        self.authorization = 'Basic ' + base64.b64encode((username + ':' + password).encode()).decode()
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def request(self, path, body=None):
        headers = {'Authorization': self.authorization, 'X-Grafana-Org-Id': '1', 'Accept': 'application/json'}
        raw = None
        if body is not None:
            raw = json.dumps(body).encode()
            headers['Content-Type'] = 'application/json'
        request = urllib.request.Request(self.origin + path, data=raw, headers=headers)
        try:
            with self.opener.open(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError('Grafana rejected operation: HTTP ' + str(error.code)) from None
        except urllib.error.URLError:
            raise RuntimeError('Grafana TLS/network unavailable') from None

    def read(self):
        return self.request('/api/dashboards/uid/' + UID)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError('Grafana redirect refused; credentials remain at the selected origin')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('read', 'publish'))
    parser.add_argument('--origin', default='https://grafana.fa.shaneque.ru')
    parser.add_argument('--username', default='admin')
    parser.add_argument('--source', type=Path)
    parser.add_argument('--expected-version', type=int)
    parser.add_argument('--capture', type=Path, required=True)
    args = parser.parse_args()
    client = Grafana(args.origin, args.username, getpass.getpass('Grafana password: '))
    before = client.read()
    permissions_before = client.request('/api/dashboards/uid/' + UID + '/permissions')
    # Capture exclusively, so a second invocation cannot replace the rollback source.
    if not args.capture.exists():
        args.capture.parent.mkdir(parents=True, exist_ok=True)
        with os.fdopen(os.open(args.capture, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w') as stream:
            json.dump(before, stream)
    result = {'uid': before['dashboard']['uid'], 'orgId': 1, 'version': before['dashboard']['version'],
              'provisioned': before['meta'].get('provisioned', False),
              'permissions_sha256': hashlib.sha256(json.dumps(permissions_before, sort_keys=True).encode()).hexdigest()}
    if args.mode == 'publish':
        if args.source is None or args.expected_version is None:
            raise ValueError('source and reviewed expected version required')
        source = json.loads(args.source.read_text(encoding='utf-8'))
        if 'dashboard' in source:
            source = source['dashboard']
        candidate = payload(source, before, args.expected_version)
        saved = client.request('/api/dashboards/db', candidate)
        after = client.read()
        if client.request('/api/dashboards/uid/' + UID + '/permissions') != permissions_before:
            raise RuntimeError('dashboard permissions changed concurrently; readback requires operator review')
        if canonical(source) != canonical(after['dashboard']):
            # Keep the complete private readback; never print its identifiers.
            path = args.capture.with_name(args.capture.stem + '-readback.private.json')
            with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w') as stream:
                json.dump(after, stream)
            raise RuntimeError('readback differs from source; inspect protected readback before accepting')
        result.update(version=after['dashboard']['version'], status=saved['status'],
                      readback='PASS', source_sha256=hashlib.sha256(canonical(source).encode()).hexdigest())
    print(json.dumps(result))


if __name__ == '__main__':
    main()
