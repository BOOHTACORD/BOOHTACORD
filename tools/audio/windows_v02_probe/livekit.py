"""Run the native audio diagnostic against a private, temporary local SFU."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import tempfile
import time
from urllib.request import urlopen

from tools.audio.research_dfn_web.livekit_windows import local_address, make_config, wildcard_listener
from tools.audio.research_v02.verify import check_output

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('server', 'client', 'web', 'result'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--server-sha256', required=True)
    args = parser.parse_args()
    result = args.result.resolve()
    check_output(result)
    if result.exists() or not result.parent.is_dir(): raise ValueError('Result must be a new local research file')
    with args.server.open('rb') as stream:
        if hashlib.file_digest(stream, 'sha256').hexdigest() != args.server_sha256:
            raise ValueError('Local SFU checksum mismatch')
    if not (args.client.parent / 'rnnoise-v02-research-only.txt').is_file():
        raise ValueError('Research client marker is missing')
    host, key, secret = local_address(), 'probe' + secrets.token_hex(8), secrets.token_urlsafe(36)
    with socket.socket() as probe: probe.bind(('127.0.0.1', 17880))
    env = dict(os.environ, BOOHTA_PROBE_KEY=key, BOOHTA_PROBE_SECRET=secret)
    tokens = json.loads(subprocess.check_output(['node', str(HERE / 'tokens.mjs'), str(args.web.resolve())], env=env))
    env.pop('BOOHTA_PROBE_KEY'); env.pop('BOOHTA_PROBE_SECRET')
    env.update(BOOHTA_PROBE_SENDER_TOKEN=tokens['sender'], BOOHTA_PROBE_RECEIVER_TOKEN=tokens['receiver'],
               BOOHTA_AUDIO_PROBE_RESULT=str(result))
    with tempfile.TemporaryDirectory(prefix='boohta-audio-local-') as directory:
        config = Path(directory) / 'server.yaml'
        config.write_text(make_config(host, key, secret), encoding='utf-8')
        server = subprocess.Popen([str(args.server.resolve()), '--config', str(config), '--node-ip', host],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)
        client = None
        try:
            for _ in range(120):
                if server.poll() is not None: raise RuntimeError('Local SFU exited')
                try:
                    with urlopen('http://127.0.0.1:17880', timeout=.3) as response:
                        if response.status == 200: break
                except OSError: time.sleep(.1)
            else: raise RuntimeError('Local SFU was not ready')
            if wildcard_listener(server.pid): raise RuntimeError('Unexpected wildcard listener')
            client = subprocess.Popen([str(args.client.resolve())], cwd=args.client.parent, env=env,
                                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)
            deadline = time.monotonic() + 90
            while client.poll() is None and time.monotonic() < deadline:
                time.sleep(.5)
                if server.poll() is not None or wildcard_listener(server.pid): raise RuntimeError('Local SFU safety check failed')
            if client.poll() is None: raise RuntimeError('Client probe timed out')
            if client.returncode != 0: raise RuntimeError('Client probe failed; inspect aggregate result')
            value = json.loads(result.read_text(encoding='utf-8'))
            if value.get('success') is not True: raise RuntimeError('Client probe did not succeed')
            print(json.dumps(value, ensure_ascii=True))
        finally:
            if client is not None and client.poll() is None: client.terminate(); client.wait(timeout=10)
            if server.poll() is None:
                server.terminate()
                try: server.wait(timeout=10)
                except subprocess.TimeoutExpired: server.kill(); server.wait(timeout=10)


if __name__ == '__main__':
    main()
