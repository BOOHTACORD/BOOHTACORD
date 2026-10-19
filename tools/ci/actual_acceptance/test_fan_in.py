import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from .fan_in import verify
from .test_validation import fixture


class FanInTests(unittest.TestCase):
    def make(self,root):
        folder=root/'sfu';folder.mkdir();row=fixture()
        report=folder/'reports/sfu-snapshot-measure/report.json';report.parent.mkdir(parents=True)
        report.write_text(json.dumps(dict(status='PASS',source_revision='a'*40,owned_resources_removed=True,actual_api_postgresql_sfu=True)))
        row['reports'][0]['sha256']=hashlib.sha256(report.read_bytes()).hexdigest()
        (folder/'result.json').write_text(json.dumps(row));return folder,report

    def test_complete_source_bound_actual_report(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary).resolve();self.make(root);verify(root,['sfu'],'a'*40,'123','2')

    def test_tamper_unknown_file_or_absent_selected_profile_fails(self):
        for case in ('tamper','unknown','missing'):
            with tempfile.TemporaryDirectory() as temporary,self.subTest(case=case):
                root=Path(temporary).resolve();folder,report=self.make(root)
                if case=='tamper':report.write_text('{}')
                if case=='unknown':(folder/'private.log').write_text('never publish raw logs')
                with self.assertRaises(ValueError):verify(root,['sfu','next'] if case=='missing' else ['sfu'],'a'*40,'123','2')
