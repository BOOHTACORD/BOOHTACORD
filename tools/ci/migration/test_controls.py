"""Focused final selector/required-gate controls; these are not eight actual GitHub PR runs."""
import json
import unittest
from tools.ci.select_changes.selection import classify
from tools.ci.actual_acceptance.plan import select
from tools.ci.required_gate.validation import validate
from tools.ci.select_changes.selection import dependency_map

JOBS=dict(changes='changes',contracts='contracts',backend='backend',web='frontend',flutter='flutter',windows='windows',actual='actual')


class MigrationControlTests(unittest.TestCase):
    def test_eight_routing_cases_and_cancelled_missing_failed_gates(self):
        for label,path in [('docs-only','docs/example.md'),('backend','backend/internal/example.go'),('web','clients/web/src/example.ts'),
            ('flutter','clients/flutter/lib/example.dart'),('windows','clients/flutter/windows/runner/example.cpp'),
            ('contracts','contracts/openapi.yaml'),('shared','tools/toolchains.json'),('unknown','new-area/example')]:
            with self.subTest(case=label):
                plan=classify([path]);risk=select([path]);selected=plan.pop('gates')
                outputs={name:str(name in selected).lower() for name in ('contracts','backend','web','flutter','windows')}
                outputs.update({k:str(v).lower() if type(v) is bool else str(v) for k,v in plan.items()})
                outputs.update(actual_profiles=json.dumps(risk['profiles']),actual_required=str(bool(risk['profiles'])).lower(),
                    actual_map_sha256=risk['map_sha256'],actual_release_required=json.dumps(risk['release_required']),actual_physical_required=json.dumps(risk['physical_required']))
                needs={JOBS[role]:{'result':'success' if role in selected or role=='changes' or role=='actual' and risk['profiles'] else 'skipped'} for role in JOBS}
                needs['changes']['outputs']=outputs;validate(needs,JOBS,dependency_map()[1])
                for result in ('failure','cancelled','skipped'):
                    needs['contracts']['result']=result
                    with self.assertRaises(ValueError):validate(needs,JOBS,dependency_map()[1])
                needs.pop('contracts')
                with self.assertRaises(ValueError):validate(needs,JOBS,dependency_map()[1])
