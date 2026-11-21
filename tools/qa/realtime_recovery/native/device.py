"""Change only this task's dedicated AVD reverse mappings."""
from contextlib import contextmanager
import subprocess


@contextmanager
def device_ports(platform, device, adb, ports):
    if platform == 'windows':
        if device != 'windows': raise ValueError('Windows desktop target required')
        yield
        return
    name = subprocess.check_output([adb, '-s', device, 'emu', 'avd', 'name'], text=True)
    if name.splitlines()[0].strip() != 'BOOHTACORD_QA_R1_1121':
        raise ValueError('Only the dedicated R1 AVD is permitted')
    existing = subprocess.check_output([adb, '-s', device, 'reverse', '--list'], text=True)
    for port in ports:
        if any(f'tcp:{port}' in row.split()[1:] for row in existing.splitlines()):
            raise ValueError('Refusing to replace an existing reverse mapping')
    added = []
    try:
        for port in ports:
            subprocess.run([adb, '-s', device, 'reverse', f'tcp:{port}', f'tcp:{port}'], check=True)
            added.append(port)
        yield
    finally:
        for port in reversed(added):
            subprocess.run([adb, '-s', device, 'reverse', '--remove', f'tcp:{port}'], check=True)
