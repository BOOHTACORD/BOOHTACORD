"""The stable Flutter status requires both complete, current execution records."""
import copy
import unittest
from . import results
from .profiles import OPERATIONS
from .artifacts import VISUALS


def record(profile):
    names = (VISUALS if profile == 'dart' else () if profile == 'android-kotlin'
             else ('app-debug.apk', 'artifact-manifest.json', 'SHA256SUMS'))
    return {'schema_version': 1, 'source_revision': 'a' * 40, 'profile': profile,
            'run_id': '123', 'run_attempt': '1', 'namespace': 'flutter', 'status': 'PASS',
            'completed': list(OPERATIONS[profile]), 'seconds': 12.5,
            'sdk': results.expected_sdk(),
            'artifacts': {name: {'bytes': 128, 'sha256': 'b' * 64} for name in names}}


class ResultTests(unittest.TestCase):
    def test_all_three_parts_required_and_kotlin_has_no_distribution_artifacts(self):
        parts = [record(p) for p in ('dart', 'android', 'android-kotlin')]
        needs = {p: {'result': 'success'} for p in ('dart', 'android', 'android-kotlin')}
        self.assertEqual(set(needs), set(results.validate(parts, needs, 'a' * 40, '123', '1')))
        for status in ('failure', 'cancelled', 'skipped', None):
            needs['android-kotlin']['result'] = status
            with self.subTest(status=status), self.assertRaises(ValueError):
                results.validate(parts, needs, 'a' * 40, '123', '1')

    def test_both_parts_are_complete_successful_and_source_bound(self):
        self.assertEqual(set(OPERATIONS), set(results.validate(
            [record(p) for p in OPERATIONS], {p: {'result': 'success'} for p in OPERATIONS},
            'a' * 40, '123', '1')))

    def test_every_absent_failed_cancelled_or_skipped_child_fails(self):
        for status in ('failure', 'cancelled', 'skipped', None):
            needs = {p: {'result': 'success'} for p in OPERATIONS}; needs['android']['result'] = status
            with self.subTest(status=status), self.assertRaises(ValueError):
                results.validate([record(p) for p in OPERATIONS], needs, 'a' * 40, '123', '1')
        with self.assertRaises(ValueError):
            results.validate([record('dart')], {'dart': {'result': 'success'}}, 'a' * 40, '123', '1')

    def test_partial_foreign_stale_forged_or_unmeasured_parts_fail(self):
        for key, bad in [('source_revision', 'c' * 40), ('run_id', '122'), ('run_attempt', '2'),
                         ('profile', 'windows'), ('namespace', 'another'), ('status', 'NOT_RUN'), ('schema_version', True),
                         ('seconds', float('nan')), ('seconds', 0), ('seconds', True),
                         ('completed', list(OPERATIONS['android'])[:-1]), ('sdk', {})]:
            parts = [record(p) for p in OPERATIONS]; parts[1][key] = bad
            with self.subTest(key=key, bad=bad), self.assertRaises(ValueError):
                results.validate(parts, {p: {'result': 'success'} for p in OPERATIONS}, 'a' * 40, '123', '1')

    def test_missing_apk_visual_and_invalid_digests_cannot_pass(self):
        for profile, name in [('android', 'app-debug.apk'), ('dart', VISUALS[0])]:
            for mutation in ('missing', 'digest', 'size'):
                parts = [record(p) for p in OPERATIONS]
                item = parts[0 if profile == 'dart' else 1]['artifacts']
                if mutation == 'missing': item.pop(name)
                elif mutation == 'digest': item[name]['sha256'] = 'not a digest'
                else: item[name]['bytes'] = 0
                with self.subTest(profile=profile, mutation=mutation), self.assertRaises(ValueError):
                    results.validate(parts, {p: {'result': 'success'} for p in OPERATIONS}, 'a' * 40, '123', '1')

    def test_duplicate_extra_and_undocumented_part_fields_are_rejected(self):
        original = [record(p) for p in OPERATIONS]
        variants = [original + [record('android')], [record('dart'), record('dart')]]
        extra = copy.deepcopy(original); extra[1]['private_payload'] = 'not permitted'; variants.append(extra)
        for parts in variants:
            with self.assertRaises(ValueError):
                results.validate(parts, {p: {'result': 'success'} for p in OPERATIONS}, 'a' * 40, '123', '1')
