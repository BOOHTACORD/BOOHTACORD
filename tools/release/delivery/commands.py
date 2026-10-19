"""Finite owned POSIX commands; no argv, stderr or unvalidated stdout in errors."""
import math
import os
import selectors
import signal
import subprocess
import time


class ExecutionFailed(RuntimeError):
    def __init__(self, code, returncode=None):
        if code not in ('start', 'exit', 'timeout', 'output', 'cleanup'):
            raise ValueError('Unknown delivery execution outcome')
        self.code, self.returncode = code, returncode
        super().__init__('Delivery command failed: ' + code)


def stop(process):
    # Every invocation owns a new session; never address another job/process tree.
    try:
        _stop(process)
    except (OSError, subprocess.TimeoutExpired):
        raise ExecutionFailed('cleanup') from None


def _stop(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(timeout=2)


def execute(argv, timeout, *, stdin=None, capture_limit=0):
    if (os.name != 'posix' or not isinstance(argv, list) or not argv
            or any(not isinstance(arg, str) or not arg or '\0' in arg for arg in argv)
            or type(timeout) not in (int, float) or not math.isfinite(timeout) or not 0 < timeout <= 900
            or type(capture_limit) is not int or not 0 <= capture_limit <= 65536):
        raise ValueError('Invalid bounded delivery command')
    process = None
    selector = None
    result = bytearray()
    try:
        try:
            process = subprocess.Popen(argv, stdin=stdin if stdin is not None else subprocess.DEVNULL,
                                       stdout=subprocess.PIPE if capture_limit else subprocess.DEVNULL,
                                       stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError:
            raise ExecutionFailed('start') from None
        deadline = time.monotonic() + timeout
        if capture_limit:
            selector = selectors.DefaultSelector()
            selector.register(process.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    raise ExecutionFailed('timeout')
                block = os.read(process.stdout.fileno(), 65536)
                if not block:
                    break
                result.extend(block)
                if len(result) > capture_limit:
                    raise ExecutionFailed('output')
        try:
            process.wait(timeout=max(0, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            raise ExecutionFailed('timeout') from None
        if process.returncode:
            raise ExecutionFailed('exit', process.returncode)
        return bytes(result)
    except BaseException:
        if process is not None:
            stop(process)
        raise
    finally:
        if selector is not None:
            selector.close()
        if process is not None and process.stdout is not None:
            process.stdout.close()
