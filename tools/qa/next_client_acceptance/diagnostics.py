"""Finite controller stages are public; exception messages and arguments are not."""
STAGES = {'production-client-build', 'capacity-stack-start', 'browser-scenario',
          'scenario-receipt', 'capacity-stack-cleanup', 'receipt-publication'}
FAILURES = {'CalledProcessError', 'TimeoutError', 'ValueError', 'OSError',
            'RuntimeError', 'FileNotFoundError', 'Error'}
CAPACITIES = {'none', 'limited', 'unlimited'}


def validate(row):
    if (not isinstance(row, dict) or set(row) != {'schema_version', 'status', 'stage', 'capacity_profile', 'failure_type'}
            or type(row['schema_version']) is not int or row['schema_version'] != 1 or row['status'] != 'FAIL'
            or row['stage'] not in STAGES or row['capacity_profile'] not in CAPACITIES or row['failure_type'] not in FAILURES):
        raise ValueError('Invalid finite controller diagnostic')
    return row
