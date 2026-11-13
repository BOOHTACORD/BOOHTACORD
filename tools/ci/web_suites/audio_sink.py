"""Provide a private virtual playback sink for headless Linux browser tests."""
from contextlib import contextmanager
import os
from pathlib import Path
import subprocess
import tempfile
import time


@contextmanager
def isolated_sink():
    with tempfile.TemporaryDirectory(prefix='boohta-firefox-audio-') as directory:
        root = Path(directory)
        socket = root / 'pulse.sock'
        runtime = root / 'runtime'
        runtime.mkdir(mode=0o700)
        config = root / 'null.pa'
        config.write_text(f'load-module module-native-protocol-unix socket={socket} auth-anonymous=1\n'
                          'load-module module-null-sink sink_name=boohta_test\n'
                          'set-default-sink boohta_test\n', encoding='utf-8')
        env = {**os.environ, 'PULSE_SERVER': 'unix:' + str(socket), 'PULSE_RUNTIME_PATH': str(runtime)}
        process = subprocess.Popen(['pulseaudio', '--daemonize=no', '--exit-idle-time=-1',
                                    '--disable-shm=true', '-n', '-F', str(config)],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
        try:
            deadline = time.monotonic() + 15
            while True:
                try:
                    result = subprocess.run(['pactl', 'info'], env=env, stdout=subprocess.DEVNULL,
                                            stderr=subprocess.DEVNULL, timeout=2, check=False)
                    if result.returncode == 0: break
                except subprocess.TimeoutExpired:
                    pass
                if process.poll() is not None: raise RuntimeError('Private audio sink exited before ready')
                if time.monotonic() >= deadline: raise RuntimeError('Private audio sink did not become ready')
                time.sleep(.2)
            yield env
        finally:
            if process.poll() is None: process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(timeout=5)
