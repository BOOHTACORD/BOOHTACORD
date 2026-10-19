"""Versioned triage thresholds never authorize ignored or retried quality assertions."""
import json
from pathlib import Path
from .triage import require


def load():
    value=json.loads(Path(__file__).with_name('policy-v1.json').read_text())
    require(value['schema_version']==1 and value['metadata_get_max_attempts']==2
            and value['retry_http_statuses']==[500,502,503,504] and value['test_retry'] is False and value['quarantined_tests']==[])
    for key in ('first_start_delay_warning_seconds','workflow_wall_warning_seconds','stuck_required_warning_seconds',
                'self_hosted_wait_warning_seconds','recurring_failure_warning_count'):
        require(type(value[key]) is int and value[key]>0)
    return value
