import tempfile
import unittest
from pathlib import Path

from tools.product_map.catalog.validation import validate_catalog
from tools.product_map.catalog.transition import validate_transition


def fixture():
    return {
        'components': [{'id': 'cmp.shared.voice', 'paths': ['src/voice.dart']}],
        'features': [{
            'id': 'voice.test', 'aliases': [], 'target_revision': 2,
            'behavior_revisions': [{'revision': 1, 'summary': 'one'},
                                   {'revision': 2, 'summary': 'two'}],
            'parity_ids': ['voice.test'], 'components': ['cmp.shared.voice'],
            'platforms': {p: {'applicability': 'SUPPORTED', 'state': 'UNKNOWN',
                              'revision': None} for p in
                          ('web', 'windows', 'macos', 'android', 'ios')},
        }],
    }


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'src').mkdir()
        (self.root / 'src/voice.dart').write_text('source')

    def test_valid_catalog_and_independent_platform_decisions(self):
        validate_catalog(fixture(), self.root, {'voice.test'})
        data = fixture()
        del data['features'][0]['platforms']['macos']
        with self.assertRaisesRegex(ValueError, 'platform'):
            validate_catalog(data, self.root, {'voice.test'})

    def test_dangling_references_and_path_traversal_fail(self):
        data = fixture()
        data['features'][0]['components'] = ['cmp.absent']
        with self.assertRaisesRegex(ValueError, 'component'):
            validate_catalog(data, self.root, {'voice.test'})
        data = fixture()
        data['components'][0]['paths'] = ['../secret']
        with self.assertRaisesRegex(ValueError, 'path'):
            validate_catalog(data, self.root, {'voice.test'})

    def test_duplicates_alias_collision_and_unknown_parity_fail(self):
        data = fixture()
        data['features'].append(dict(data['features'][0]))
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            validate_catalog(data, self.root, {'voice.test'})
        data = fixture()
        data['features'][0]['aliases'] = ['voice.test']
        with self.assertRaisesRegex(ValueError, 'alias'):
            validate_catalog(data, self.root, {'voice.test'})
        data = fixture()
        with self.assertRaisesRegex(ValueError, 'parity'):
            validate_catalog(data, self.root, set())

    def test_feature_revision_is_not_application_version(self):
        data = fixture()
        data['features'][0]['platforms']['web'].update(state='IMPLEMENTED', revision=0)
        with self.assertRaisesRegex(ValueError, 'revision'):
            validate_catalog(data, self.root, {'voice.test'})
        data = fixture()
        data['features'][0].update(target_revision=None, behavior_revisions=[])
        validate_catalog(data, self.root, {'voice.test'})

    def test_cycle_and_missing_dependency_fail(self):
        data = fixture()
        data['features'][0]['depends_on'] = ['voice.test']
        with self.assertRaisesRegex(ValueError, 'cycle'):
            validate_catalog(data, self.root, {'voice.test'})
        data['features'][0]['depends_on'] = ['voice.missing']
        with self.assertRaisesRegex(ValueError, 'dependency'):
            validate_catalog(data, self.root, {'voice.test'})

    def test_exception_requires_reviewable_reason_and_issue(self):
        data = fixture()
        item = data['features'][0]['platforms']['ios']
        item.update(applicability='PLATFORM_EXCEPTION', reason='OS restriction',
                    owner='client', tracking_issue=688)
        with self.assertRaisesRegex(ValueError, 'exception'):
            validate_catalog(data, self.root, {'voice.test'})
        item.update(alternative='browser', review_date='2027-01-01')
        validate_catalog(data, self.root, {'voice.test'})
        item['tracking_issue'] = True
        with self.assertRaisesRegex(ValueError, 'exception'):
            validate_catalog(data, self.root, {'voice.test'})

    def test_prior_revision_is_immutable_and_id_cannot_disappear(self):
        old = fixture()
        new = fixture()
        new['features'][0]['behavior_revisions'][0]['summary'] = 'rewritten'
        with self.assertRaisesRegex(ValueError, 'revision'):
            validate_transition(old, new)
        new = fixture()
        new['features'] = []
        with self.assertRaisesRegex(ValueError, 'removed'):
            validate_transition(old, new)
        data = fixture()
        data['features'][0]['behavior_revisions'][0]['revision'] = 2
        with self.assertRaisesRegex(ValueError, 'revision'):
            validate_catalog(data, self.root, {'voice.test'})

    def test_unknown_target_may_be_curated_without_inventing_history(self):
        old = fixture()
        old['features'][0].update(target_revision=None, behavior_revisions=[])
        validate_transition(old, fixture())
        with self.assertRaisesRegex(ValueError, 'revision'):
            validate_transition(fixture(), old)
