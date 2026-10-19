"""Measurement ingestion cannot borrow another run's or partial dataset."""
import json
from pathlib import Path
import tempfile
import unittest
from . import measure
from .test_comparison import fixture,SOURCE


class InputTests(unittest.TestCase):
    def populate(self,root):
        run,jobs,needs,old,new=fixture()
        for kind,rows in [('legacy',old),('fan-in',new)]:
            for row in rows:
                name='web-'+kind+'-'+row['execution']['namespace']+'-'+SOURCE+'-123-1'
                directory=root/name;directory.mkdir()
                (directory/('web-legacy.json' if kind=='legacy' else 'web-fan-in.json')).write_text(json.dumps(row))
        return old,new

    def test_exact_six_current_sample_reports_can_be_read(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name);old,new=self.populate(root)
            self.assertEqual(measure.read_inputs(root,SOURCE,123,1),(old,new))

    def test_missing_foreign_extra_or_indirect_sample_is_rejected(self):
        for change in ('missing','foreign','extra','symlink'):
            with tempfile.TemporaryDirectory() as name:
                root=Path(name);self.populate(root);directory=next(root.iterdir())
                if change=='missing':next(directory.iterdir()).unlink()
                if change=='foreign':directory.rename(root/(directory.name+'-foreign'))
                if change=='extra':(directory/'private.log').write_text('CANARY')
                if change=='symlink':
                    target=next(directory.iterdir());target.unlink();target.symlink_to(root/'missing')
                with self.subTest(change=change),self.assertRaises(ValueError):measure.read_inputs(root,SOURCE,123,1)
