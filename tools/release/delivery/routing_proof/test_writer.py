import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from .. import routing,api as reader_api
from . import record as route_proof
from tools.release.windows_promotion.noop_readback.test_support import API
from tools.release.windows_promotion.intent import REPOSITORY


class RouteProofWriterTests(unittest.TestCase):
    def test_real_routing_entrypoint_retains_exact_proof_before_emitting_outputs(self):
        api=API()
        class Reader:
            def read(self):return api.runs[123]
            def collection(self,name):return {'total_count':6,'jobs':api.jobs(123)}
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);output=root/'outputs'
            env={'GITHUB_REPOSITORY':REPOSITORY,'BUILD_RUN_ID':'123','GITHUB_TOKEN':'never-retain-token',
                'GITHUB_SHA':'b'*40,'GITHUB_EVENT_NAME':'workflow_run','GITHUB_RUN_ID':'456',
                'GITHUB_RUN_ATTEMPT':'2','GITHUB_OUTPUT':str(output)}
            with patch.dict(os.environ,env),patch.object(reader_api,'Reader',return_value=Reader()),\
                 patch.object(route_proof,'ROOT',root):
                routing.main()
                raw=(root/'.out/delivery-route/route.json').read_text()
                self.assertEqual(json.loads(raw),api.route)
                self.assertNotIn('never-retain-token',raw)
                self.assertIn('has_bundle=false\n',output.read_text())
                output.unlink()
                with patch.object(route_proof,'publish',side_effect=OSError('owned synthetic failure')):
                    with self.assertRaises(OSError):routing.main()
                self.assertFalse(output.exists())
