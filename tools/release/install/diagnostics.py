"""Bounded, non-secret phase diagnostics for the trusted installer."""
import argparse
import json
import os
from pathlib import Path
import stat


INSTALL_PHASES = frozenset({
    'installer_start', 'argument_validation', 'bundle_checksum', 'release_lock',
    'disk_budget', 'docker_preflight', 'bundle_extract', 'bundle_verification',
    'running_release_check', 'compatibility_check', 'state_observation',
    'runtime_extract', 'attachment_headroom', 'release_directory',
    'environment_prepare', 'image_load', 'deployment', 'runtime_verification',
    'readback', 'installation_receipt', 'remote_setup', 'remote_arguments',
    'remote_stage', 'remote_files', 'remote_trust', 'remote_checksum',
    'installer_workspace', 'driver_extract', 'installer_bootstrap',
    'diagnostic_unavailable',
})
MAX_RESPONSE_BYTES = 1024
BASE_RESPONSE = {'schema_version', 'kind', 'status'}


def success_response():
    return {'schema_version': 1, 'kind': 'install-result', 'status': 'PASS'}


def failure_response(phase):
    if not isinstance(phase, str) or phase not in INSTALL_PHASES:
        raise ValueError('Unknown installer failure phase')
    return {'schema_version': 1, 'kind': 'install-result', 'status': 'FAIL', 'phase': phase}


class FailureReceipt:
    def __init__(self, path):
        self.path = Path(path) if path is not None else None
        self.phase = 'installer_start'

    def mark(self, phase):
        if not isinstance(phase, str) or phase not in INSTALL_PHASES:
            raise ValueError('Unknown installer failure phase')
        self.phase = phase

    def write(self):
        if self.path is None:
            return False
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0)
        data = (json.dumps(failure_response(self.phase), separators=(',', ':'), sort_keys=True) + '\n').encode()
        try:
            descriptor = os.open(self.path, flags, 0o600)
            with os.fdopen(descriptor, 'wb') as target:
                target.write(data)
                target.flush()
                os.fsync(target.fileno())
            return True
        except OSError:
            return False


def _unique(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError('Duplicate installer response field')
        value[key] = item
    return value


def validate_response(raw):
    if isinstance(raw, str):
        raw = raw.encode('utf-8')
    if not isinstance(raw, bytes) or not 0 < len(raw) <= MAX_RESPONSE_BYTES:
        raise ValueError('Invalid installer response size')
    value = json.loads(raw, object_pairs_hook=_unique)
    if (not isinstance(value, dict) or type(value.get('schema_version')) is not int
            or value.get('schema_version') != 1 or value.get('kind') != 'install-result'):
        raise ValueError('Invalid installer response identity')
    status = value.get('status')
    if status == 'PASS':
        if set(value) != BASE_RESPONSE:
            raise ValueError('Invalid installer success response')
    elif status == 'FAIL':
        if (set(value) != BASE_RESPONSE | {'phase'} or not isinstance(value['phase'], str)
                or value['phase'] not in INSTALL_PHASES):
            raise ValueError('Invalid installer failure response')
    else:
        raise ValueError('Invalid installer response status')
    return value


def read_response(path):
    path = Path(path)
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_size > MAX_RESPONSE_BYTES:
        raise ValueError('Invalid installer response file')
    return validate_response(path.read_bytes())


def publish_response(path):
    try:
        response = read_response(path)
        if response['status'] != 'FAIL':
            raise ValueError('Expected failed installer receipt')
        return response
    except (OSError, ValueError, TypeError, UnicodeError):
        return failure_response('diagnostic_unavailable')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=('publish',))
    parser.add_argument('path', type=Path)
    args = parser.parse_args()
    response = publish_response(args.path)
    print(json.dumps(response, separators=(',', ':'), sort_keys=True))


if __name__ == '__main__':
    main()
