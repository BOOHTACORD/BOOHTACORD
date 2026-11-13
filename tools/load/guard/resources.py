"""Observe the owned API container through its private Prometheus metrics."""
import os
import subprocess
import threading
import time
from .metrics import snapshot
from .ownership import owned
from .sample_failure import SampleFailure
from tools.qa.client_lifecycle.services import output


class Resources:
    def __init__(self, stack):
        self.stack, self.previous = stack, None
        self.lock = threading.Lock()

    def read(self):
        with self.lock:
            return self._read()

    def _read(self):
        container = owned(self.stack, 'api')
        if self.stack.api != container:
            raise ValueError('Owned API container is not active')
        try:
            nanos = int(output('docker', 'inspect', container, '--format', '{{.HostConfig.NanoCpus}}'))
        except (OSError, subprocess.SubprocessError, ValueError) as exc:
            raise ValueError('Owned API CPU quota unavailable') from exc
        if nanos <= 0:
            raise ValueError('Owned API CPU quota must be bounded')
        cpu_limit = min(nanos / 1_000_000_000, os.cpu_count() or 1)
        try:
            values = snapshot()
        except (OSError, ValueError):
            raise SampleFailure('resource_metrics') from None
        now = time.monotonic()
        try:
            cpu_seconds = values['process_cpu_seconds_total']
            rss = int(values['process_resident_memory_bytes'])
            free = int(values['voice_platform_attachment_filesystem_available_bytes'])
        except (KeyError, TypeError, ValueError):
            raise ValueError('Owned API resource metrics are incomplete') from None
        if self.previous is not None and now <= self.previous[0]:
            raise ValueError('Owned API resource sample interval is invalid')
        cpu = 0 if self.previous is None else (
            100*(cpu_seconds-self.previous[1])/(now-self.previous[0])/cpu_limit)
        if rss < 0 or free < 0 or (self.previous is not None and cpu_seconds < self.previous[1]):
            raise ValueError('Owned API resource metrics are invalid')
        self.previous = now, cpu_seconds
        return dict(CPUPercent=cpu, RSSBytes=rss, FreeBytes=free)
