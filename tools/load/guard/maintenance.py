"""Single reversible state change on the verified disposable load database."""
import threading

from .ownership import query, verify_marker


class FixtureMaintenance:
    def __init__(self, stack, manifest):
        self.stack, self.manifest = stack, manifest
        self.lock = threading.Lock()
        self.changed = False

    def activate(self):
        with self.lock:
            verify_marker(self.stack, self.manifest['Nonce'], len(self.manifest['Accounts']))
            if self.changed:
                raise ValueError('Maintenance change already requested')
            changed = query(self.stack, "WITH changed AS (UPDATE maintenance_admission SET active=true, changed_at=now() WHERE singleton=true AND active=false RETURNING 1) SELECT count(*) FROM changed;")
            if changed != '1':
                raise ValueError('Fixture maintenance was not initially inactive')
            self.changed = True

    def restore(self):
        with self.lock:
            if self.changed:
                verify_marker(self.stack, self.manifest['Nonce'], len(self.manifest['Accounts']))
                query(self.stack, "UPDATE maintenance_admission SET active=false, changed_at=now() WHERE singleton=true;")
                self.changed = False
