"""Grant microphone permission only during the isolated Android QA capture."""
from contextlib import contextmanager
import subprocess
import threading

TARGET = 'integration_test/android_noise_sfu_test.dart'


@contextmanager
def android_microphone_permission(platform, device, target):
    if platform != 'android' or target != TARGET:
        yield
        return
    if not device.startswith('emulator-'):
        raise ValueError('Microphone QA requires the verified QA emulator')
    stop = threading.Event()

    def grant_while_running():
        command = ['adb', '-s', device, 'shell', 'pm', 'grant',
                   'ru.boohtacord.app', 'android.permission.RECORD_AUDIO']
        while not stop.is_set():
            try:
                subprocess.run(command, stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL, timeout=2, check=False)
            except (OSError, subprocess.TimeoutExpired):
                pass
            stop.wait(.5)

    worker = threading.Thread(target=grant_while_running, daemon=True)
    worker.start()
    try:
        yield
    finally:
        stop.set()
        worker.join(timeout=3)
