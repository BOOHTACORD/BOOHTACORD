"""Send one Android Back key only after the required-update screen is captured."""
import re
import subprocess
import threading
from contextlib import contextmanager


@contextmanager
def android_back_on_capture(platform, device, target, destination, *,
                            runner=subprocess.run, timeout=5):
    if platform != 'android' or target != 'integration_test/update_required_test.dart':
        yield
        return
    if not re.fullmatch(r'emulator-[0-9]+', device):
        raise ValueError('Android Back check requires the verified QA emulator')
    marker = destination / 'android-required-update.png'
    if marker.exists():
        raise ValueError('Android Back check requires a fresh capture directory')
    stopped, finished = threading.Event(), threading.Event()
    errors = []

    def send_when_ready():
        try:
            while not stopped.wait(0.05):
                if marker.is_file() and marker.stat().st_size:
                    if stopped.wait(0.2):
                        return
                    runner(['adb', '-s', device, 'shell', 'input', 'keyevent', 'KEYCODE_BACK'],
                           check=True, timeout=10)
                    return
        except BaseException as error:
            errors.append(error)
        finally:
            finished.set()

    worker = threading.Thread(target=send_when_ready, daemon=True)
    worker.start()
    try:
        yield
    except BaseException:
        stopped.set()
        worker.join(timeout=12)
        raise
    else:
        ready = finished.wait(timeout)
        stopped.set()
        worker.join(timeout=12)
        if not ready or errors:
            raise RuntimeError('Android Back event was not sent successfully') from (errors[0] if errors else None)
