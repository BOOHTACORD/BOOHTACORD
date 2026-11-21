"""Grant microphone permission only during the isolated Android QA capture."""
from contextlib import contextmanager
import subprocess
import threading

TARGETS = {
    'integration_test/android_noise_sfu_test.dart',
    'integration_test/issue785_background_microphone_uplink_test.dart',
}


@contextmanager
def android_microphone_permission(platform, device, target, *, regrant=True):
    if platform != 'android' or target not in TARGETS:
        yield
        return
    if not device.startswith('emulator-'):
        raise ValueError('Microphone QA requires the verified QA emulator')
    command = ['adb', '-s', device, 'shell', 'pm', 'grant',
               'ru.boohtacord.app', 'android.permission.RECORD_AUDIO']
    stop = threading.Event()

    def grant_while_running():
        while not stop.is_set():
            try:
                result = subprocess.run(
                    command,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=2,
                    check=False,
                )
                if not regrant and result.returncode == 0:
                    return
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
