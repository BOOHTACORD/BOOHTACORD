"""Run a research browser gate against a temporary, local Windows LiveKit."""
import argparse
import ipaddress
import os
import secrets
import socket
import subprocess
import tempfile
import time
from pathlib import Path
from urllib.request import urlopen

PRIVATE = tuple(ipaddress.ip_network(value) for value in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'))


def is_private_test_ip(value):
    try:
        address = ipaddress.ip_address(value)
        return address.version == 4 and any(address in block for block in PRIVATE)
    except ValueError:
        return False


def make_config(host, key, secret):
    if not is_private_test_ip(host) or not key.replace('-', '').replace('_', '').isalnum() or not secret.replace('-', '').replace('_', '').isalnum():
        raise ValueError('Invalid local server configuration')
    return (f'port: 17880\nbind_addresses:\n  - 127.0.0.1\nkeys:\n  {key}: {secret}\n'
            f'rtc:\n  tcp_port: 0\n  port_range_start: 21400\n  port_range_end: 21420\n'
            f'  use_external_ip: false\n  enable_loopback_candidate: true\n'
            f'  ips:\n    includes:\n      - {host}/32\n')


def probe_environment(inherited, key, secret):
    return dict(inherited, RNNOISE_LIVEKIT_URL='ws://127.0.0.1:17880',
                RNNOISE_LIVEKIT_API_KEY=key, RNNOISE_LIVEKIT_API_SECRET=secret)


def local_address():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.connect(('192.0.2.1', 9))  # Selects a route; sends no datagram.
        host = probe.getsockname()[0]
    if not is_private_test_ip(host):
        raise RuntimeError('No private interface for local RTC candidates')
    return host


def wildcard_listener(pid):
    for protocol in ('TCP', 'UDP'):
        output = subprocess.check_output(['netstat', '-ano', '-p', protocol], text=True, errors='replace')
        for line in output.splitlines():
            fields = line.split()
            if fields and fields[-1] == str(pid) and len(fields) > 2 and fields[1].startswith(('0.0.0.0:', '[::]:')):
                return True
    return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', required=True, type=Path)
    parser.add_argument('--web', required=True, type=Path)
    parser.add_argument('--config', default='tests/audio/playwright.deepfilter.config.ts')
    parser.add_argument('--test', default='deepfilter_livekit')
    args = parser.parse_args()
    host, key, secret = local_address(), 'probe' + secrets.token_hex(8), secrets.token_urlsafe(36)
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 17880))
    env = probe_environment(os.environ, key, secret)
    with tempfile.TemporaryDirectory(prefix='boohta-livekit-') as directory:
        config = Path(directory) / 'server.yaml'
        config.write_text(make_config(host, key, secret), encoding='utf-8')
        server = subprocess.Popen([str(args.binary.resolve()), '--config', str(config), '--node-ip', host],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                  creationflags=subprocess.CREATE_NO_WINDOW)
        child = None
        try:
            for _ in range(120):
                if server.poll() is not None:
                    raise RuntimeError('LiveKit exited before readiness')
                try:
                    with urlopen('http://127.0.0.1:17880', timeout=.3) as response:
                        if response.status == 200: break
                except OSError:
                    time.sleep(.1)
            else:
                raise RuntimeError('Local LiveKit readiness timeout')
            if wildcard_listener(server.pid): raise RuntimeError('Unexpected wildcard listener')
            child = subprocess.Popen(['node', 'node_modules/@playwright/test/cli.js', 'test',
                                      '--config', args.config, args.test], cwd=args.web, env=env,
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            deadline = time.monotonic() + 150
            while child.poll() is None and time.monotonic() < deadline:
                time.sleep(.5)
                if server.poll() is not None: raise RuntimeError('Local LiveKit exited unexpectedly')
                if wildcard_listener(server.pid): raise RuntimeError('Unexpected wildcard listener')
            if child.poll() is None: raise RuntimeError('Browser test timed out')
            if child.returncode != 0: raise RuntimeError('Browser test failed')
            print('Local browser LiveKit test passed')
        finally:
            if child is not None and child.poll() is None:
                child.terminate(); child.wait(timeout=10)
            if server.poll() is None:
                server.terminate()
                try: server.wait(timeout=10)
                except subprocess.TimeoutExpired: server.kill(); server.wait(timeout=10)


if __name__ == '__main__':
    main()
