"""Run the research gate against a caller-supplied loopback LiveKit binary."""
import argparse
import socket
import subprocess
import time
from pathlib import Path
from urllib.request import urlopen


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary', required=True, type=Path)
    parser.add_argument('--web', required=True, type=Path)
    parser.add_argument('--config', default='tests/audio/playwright.deepfilter.config.ts')
    parser.add_argument('--test', default='deepfilter_livekit')
    args = parser.parse_args()
    for kind, port in [(socket.SOCK_STREAM, 17880), (socket.SOCK_STREAM, 17881), (socket.SOCK_DGRAM, 7882)]:
        with socket.socket(socket.AF_INET, kind) as probe:
            probe.bind(('127.0.0.1', port))
    command = [str(args.binary), '--dev', '--bind', '127.0.0.1', '--node-ip', '127.0.0.1',
               '--port', '17880', '--rtc.tcp_port', '17881', '--rtc.enable_loopback_candidate']
    with subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                          creationflags=subprocess.CREATE_NO_WINDOW) as server:
        try:
            for _ in range(30):
                if server.poll() is not None:
                    raise RuntimeError('LiveKit exited before readiness')
                try:
                    with urlopen('http://127.0.0.1:17880', timeout=1) as response:
                        if response.status == 200:
                            break
                except OSError:
                    time.sleep(.5)
            else:
                raise RuntimeError('LiveKit readiness timeout')
            subprocess.run(['npx.cmd', 'playwright', 'test', '--config', args.config,
                            args.test], cwd=args.web, check=True)
        finally:
            server.terminate()
            server.wait(timeout=10)


if __name__ == '__main__':
    main()
