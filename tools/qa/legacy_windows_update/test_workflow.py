"""The actual legacy EXE acceptance must run, not just its offline guards."""
import copy
from pathlib import Path
import unittest
import yaml

ROOT=Path(__file__).resolve().parents[3]
COMMAND='python -m tools.qa.legacy_windows_update.run'


def validate(document):
    steps=document['jobs']['windows-gui-sfu']['steps']
    found=[s for s in steps if s.get('run')==COMMAND]
    if len(found)!=1 or found[0].get('if') or found[0].get('continue-on-error'):
        raise ValueError('Actual old-client acceptance must not be skipped')
    current=next(i for i,s in enumerate(steps) if s.get('run')=='python -m tools.ci.windows_gates.acceptance')
    if steps.index(found[0])>=current: raise ValueError('Old-client fixture needs a fresh profile first')
    unit=[s for s in steps if s.get('run')=='python -m unittest tools.qa.legacy_windows_update.test_owned']
    if (len(unit)!=1 or unit[0].get('if') or unit[0].get('continue-on-error') or
            steps.index(unit[0])>=steps.index(found[0])):
        raise ValueError('Windows directory-lock regression must run before the actual journey')
    kept=[s for s in steps if s.get('with',{}).get('path')=='.out/legacy-windows-update/']
    if len(kept)!=1 or kept[0].get('if')!='always()' or kept[0]['with'].get('if-no-files-found')!='error':
        raise ValueError('Native result and synthetic captures must be retained')


class WorkflowTests(unittest.TestCase):
    def document(self):
        return yaml.load((ROOT/'.github/workflows/flutter-windows.yaml').read_text(),Loader=yaml.BaseLoader)

    def test_actual_hosted_journey_is_mandatory(self): validate(self.document())

    def test_windows_lock_regression_cannot_be_skipped_or_replaced_with_linux_only(self):
        for change in ['missing','skipped','ignored','late']:
            document=self.document();steps=document['jobs']['windows-gui-sfu']['steps']
            unit=next(s for s in steps if s.get('run')=='python -m unittest tools.qa.legacy_windows_update.test_owned')
            if change=='missing':steps.remove(unit)
            if change=='skipped':unit['if']='false'
            if change=='ignored':unit['continue-on-error']='true'
            if change=='late':steps.remove(unit);steps.append(unit)
            with self.subTest(change=change),self.assertRaises(ValueError):validate(document)

    def test_missing_skipped_ignored_late_or_unretained_acceptance_is_rejected(self):
        for change in ['missing','skipped','ignored','late','capture']:
            document=copy.deepcopy(self.document());steps=document['jobs']['windows-gui-sfu']['steps']
            actual=next(s for s in steps if s.get('run')==COMMAND)
            if change=='missing': steps.remove(actual)
            if change=='skipped': actual['if']='false'
            if change=='ignored': actual['continue-on-error']='true'
            if change=='late': steps.remove(actual);steps.append(actual)
            if change=='capture': steps[:]=[s for s in steps if s.get('with',{}).get('path')!='.out/legacy-windows-update/']
            with self.subTest(change=change),self.assertRaises(ValueError):validate(document)
