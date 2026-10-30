"""Finite delivery stages with public timing, not command output or credentials."""
import re
import time
from .commands import execute, ExecutionFailed, MAX_COMMAND_TIMEOUT_SECONDS

LIMITS = {'current_revision': 45, 'history': 10, 'transfer_bundle': MAX_COMMAND_TIMEOUT_SECONDS,
          'transfer_driver': 60, 'remote_install': 600, 'readback': 45}


class PhaseFailed(RuntimeError):
    pass


class ReportedFailure(Exception):
    """A remote command returned a validated, finite failure phase."""
    def __init__(self, phase):
        if not isinstance(phase, str) or not re.fullmatch('[a-z][a-z0-9_]{0,63}', phase):
            raise ValueError('Invalid reported delivery phase')
        self.phase = phase
        super().__init__('Remote delivery stage failed')


class Phases:
    def __init__(self, source, controller, *, executor=execute, clock=time.monotonic):
        if any(not isinstance(v, str) or not re.fullmatch('[a-f0-9]{40}', v) for v in (source, controller)):
            raise ValueError('Full delivery source and controller identities required')
        self.source, self.controller, self.execute, self.clock = source, controller, executor, clock
        self.rows = []

    def run(self, name, argv, *, validator=None, stdin=None, capture_limit=0):
        index = len(self.rows)
        if (index >= len(LIMITS) or name != tuple(LIMITS)[index]
                or any(row['status'] != 'PASS' for row in self.rows)):
            raise ValueError('Delivery cannot skip, repeat or continue after a failed stage')
        row = {'phase': name, 'limit_seconds': LIMITS[name], 'status': 'FAIL',
               'failure_code': None, 'exit_code': None, 'elapsed_seconds': 0}
        started = self.clock()
        self.rows.append(row)
        try:
            result = self.execute(argv, LIMITS[name], stdin=stdin, capture_limit=capture_limit)
            if validator is not None:
                try:
                    result = validator(result)
                except ReportedFailure:
                    raise
                except Exception:
                    row['failure_code'] = 'invalid_output'
                    raise PhaseFailed('Delivery result validation failed') from None
            row['status'] = 'PASS'
            return result
        except ReportedFailure as error:
            row['failure_code'] = 'installer_' + error.phase
            raise PhaseFailed('Delivery stage failed: ' + name) from None
        except ExecutionFailed as error:
            row['failure_code'], row['exit_code'] = error.code, error.returncode
            raise PhaseFailed('Delivery stage failed: ' + name) from None
        except PhaseFailed:
            raise
        except Exception:
            row['failure_code'] = 'execution'
            raise PhaseFailed('Delivery stage execution failed: ' + name) from None
        except BaseException:
            row['failure_code'] = 'interrupted'
            raise
        finally:
            row['elapsed_seconds'] = round(self.clock() - started, 6)

    def _report(self, status):
        return {'schema_version': 1, 'kind': 'delivery-phases', 'source_revision': self.source,
                'controller_revision': self.controller, 'status': status,
                'phases': [dict(row) for row in self.rows]}

    def complete(self):
        if len(self.rows) != len(LIMITS) or any(row['status'] != 'PASS' for row in self.rows):
            raise ValueError('Incomplete delivery cannot be reported successful')
        return self._report('PASS')

    def failure(self):
        return self._report('FAIL')
