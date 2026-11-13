"""Bounded reversible faults, only on resources created by this controller."""
import subprocess
import threading
from .ownership import owned, query


class Faults:
    def __init__(self, stack):
        self.stack, self.paused, self.processes = stack, set(), []
        self.lock, self.timer, self.current, self.generation = threading.RLock(), None, None, None
        self.pressure = stack.work/'attachments/load-pressure.bin'

    def apply(self, name):
        if name not in ('db_pressure', 'sfu_outage', 'slow_telemetry', 'disk_pressure', 'restore'):
            raise ValueError('Unknown bounded fault')
        with self.lock:
            if name == 'restore':
                self.restore()
                return
            self.restore()
            if name in ('sfu_outage', 'slow_telemetry'):
                role = 'sfu' if name == 'sfu_outage' else 'tempo'
                target = owned(self.stack, role)
                subprocess.run(['docker', 'pause', target], check=True, capture_output=True, timeout=5)
                self.paused.add(role)
            elif name == 'db_pressure':
                target = owned(self.stack, 'db')
                command = ['docker', 'exec', '-e', 'PGAPPNAME=qa_load_fault', target, 'psql', '-U', 'qa', '-d', 'qa', '-XAt', '-c',
                           "BEGIN; SET LOCAL statement_timeout='2500ms'; LOCK users IN ACCESS EXCLUSIVE MODE; SELECT pg_sleep(2); ROLLBACK;"]
                self.processes.append(subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            else:
                self.pressure.parent.mkdir(exist_ok=True)
                if not self.pressure.resolve().is_relative_to(self.stack.work.resolve()):
                    raise ValueError('Foreign pressure volume')
                with self.pressure.open('xb') as stream:
                    for _ in range(32):
                        stream.write(bytes(1 << 20))
            self.current = name
            self.generation = object()
            self.timer = threading.Timer(2, self.restore)
            self.timer.daemon = True
            self.timer.start()

    def active(self, name):
        with self.lock:
            if self.current != name:
                return False
            generation = self.generation
            process = self.processes[0] if self.processes else None
            paused = set(self.paused)
        active = False
        if name == 'disk_pressure':
            active = self.pressure.is_file() and self.pressure.stat().st_size == 32 << 20
        elif name in ('sfu_outage', 'slow_telemetry'):
            role = 'sfu' if name == 'sfu_outage' else 'tempo'
            result = subprocess.run(['docker', 'inspect', owned(self.stack, role), '--format', '{{.State.Paused}}'],
                                    check=True, capture_output=True, text=True, timeout=5)
            active = role in paused and result.stdout.strip() == 'true'
        elif name == 'db_pressure' and process and process.poll() is None:
            sql = ("SELECT EXISTS (SELECT 1 FROM pg_locks l JOIN pg_stat_activity a ON a.pid=l.pid "
                   "WHERE a.application_name='qa_load_fault' AND l.relation='users'::regclass "
                   "AND l.mode='AccessExclusiveLock' AND l.granted);")
            active = query(self.stack, sql) == 't' and process.poll() is None
        with self.lock:
            return active and self.generation is generation

    def restore(self):
        with self.lock:
            self.current = None
            self.generation = None
            if self.timer:
                self.timer.cancel()
                self.timer = None
            for role in tuple(self.paused):
                subprocess.run(['docker', 'unpause', owned(self.stack, role)], check=True, capture_output=True, timeout=5)
                self.paused.remove(role)
            for process in self.processes:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
            self.processes.clear()
            self.pressure.unlink(missing_ok=True)
