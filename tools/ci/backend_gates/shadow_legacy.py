"""Original full check coverage in its sequential order, using current source."""
import json
import time
from tools.ci.native import backend
from tools.ci.native.process import ROOT
from .run import checked_source, load_smoke
from .results import execution
from .shadow_compare import LEGACY_OPERATIONS, REFERENCE_REVISION


def execute():
    path=ROOT/'.out/ci/backend-shadow-legacy.json';path.parent.mkdir(parents=True,exist_ok=True)
    row={'status':'FAIL'};path.write_text(json.dumps(row)+'\n')
    source=checked_source()
    row.update(schema_version=1,source_revision=source,execution=execution(),coverage_reference_revision=REFERENCE_REVISION)
    started=time.monotonic()
    try:
        # This preserves database preflight, uncached complete Go tests,
        # mandatory no-skip verification, supplemental two-installation telemetry,
        # vet/build, matrix and all five API loads.
        backend.main()
        load_smoke()
        if checked_source()!=source:raise ValueError('Backend shadow source changed')
        row.update(status='PASS',operations=list(LEGACY_OPERATIONS))
    finally:
        row['seconds']=time.monotonic()-started
        path.write_text(json.dumps(row,sort_keys=True)+'\n')


if __name__=='__main__':execute()
