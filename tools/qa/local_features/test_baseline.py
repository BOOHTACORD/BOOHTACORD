import json
import hashlib
import tempfile
import unittest
from pathlib import Path
from .baseline import approve, comparison, compare

class BaselineTests(unittest.TestCase):
    def test_cannot_approve_failed_or_empty_run(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t)
            for status,shots in [('FAIL',[{'path':'a.png'}]),('REVIEW_REQUIRED',[])]:
                (root/'report.json').write_text(json.dumps({'status':status,'screenshots':shots}))
                with self.assertRaises(ValueError): approve(root,root/'baseline','checked')
    def test_comparison_reports_new_changed_and_missing(self):
        before={'a':{'sha256':'1'},'b':{'sha256':'2'}}
        after={'a':{'sha256':'3'},'c':{'sha256':'4'}}
        self.assertEqual(comparison(before,after),{'a':'CHANGED','b':'MISSING','c':'NEW'})

    def test_reference_requires_explicit_review(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t)
            for review in [None, 'NOT_RUN', {'status':'PARTIAL_REVIEW'}]:
                (root/'report.json').write_text(json.dumps({'screenshots':[], 'visual_review':review}))
                with self.assertRaises(ValueError): compare(root,root,root/'comparison')
    def test_approval_rejects_modified_screenshot(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t);(root/'a.png').write_bytes(b'changed')
            (root/'report.json').write_text(json.dumps({'status':'REVIEW_REQUIRED',
                'screenshots':[{'path':'a.png','sha256':'original'}]}))
            with self.assertRaises(ValueError): approve(root,root/'baseline','reviewed')
            self.assertFalse((root/'baseline').exists())

    def test_comparison_rejects_changed_reference_or_current_pixels(self):
        for modified in ['before', 'after']:
            with self.subTest(modified=modified), tempfile.TemporaryDirectory() as t:
                root=Path(t)
                for name in ['before','after']:
                    folder=root/name;folder.mkdir()
                    (folder/'a.png').write_bytes(b'original')
                    report={'screenshots':[{'name':'a','path':'a.png',
                        'sha256':hashlib.sha256(b'original').hexdigest()}],
                        'visual_review':{'status':'REVIEWED'}}
                    (folder/'report.json').write_text(json.dumps(report))
                (root/modified/'a.png').write_bytes(b'changed')
                with self.assertRaises(ValueError):
                    compare(root/'before',root/'after',root/'comparison')
                self.assertFalse((root/'comparison').exists())
