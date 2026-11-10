import json
import tempfile
import unittest
from pathlib import Path

from tools.product_map.ownership.scopes import validate_feature_scopes
from tools.product_map.catalog.curated import load_curated_catalog
from tools.product_map.impact.analyze import analyze


class ScopeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'backend/internal/identity/register_user').mkdir(parents=True)

    def test_existing_leaf_is_allowed(self):
        validate_feature_scopes([{'id': 'auth.registration',
            'components': ['cmp.reg'], 'owned_roots': [
                {'path': 'backend/internal/identity/register_user/', 'component': 'cmp.reg'}]}], self.root)

    def test_aggregate_traversal_wildcard_and_missing_scope_are_rejected(self):
        for path in ('backend/internal/identity/', 'backend/internal/../identity/',
                     'backend/internal/identity/register_user/*',
                     'backend/internal/identity/missing/', '/backend/internal/identity/register_user/'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                validate_feature_scopes([{'id': 'x', 'components': ['cmp.x'],
                                          'owned_roots': [{'path': path, 'component': 'cmp.x'}]}], self.root)

    def test_overlapping_feature_scopes_require_explicit_resolution(self):
        (self.root / 'backend/internal/identity/register_user/api').mkdir()
        rows = [{'id': 'one', 'components': ['cmp.one'], 'owned_roots': [
                    {'path': 'backend/internal/identity/register_user/', 'component': 'cmp.one'}]},
                {'id': 'two', 'components': ['cmp.two'], 'owned_roots': [
                    {'path': 'backend/internal/identity/register_user/api/', 'component': 'cmp.two'}]}]
        with self.assertRaisesRegex(ValueError, 'overlap'):
            validate_feature_scopes(rows, self.root)

    def test_scope_requires_a_component_linked_to_that_feature(self):
        item = {'id': 'one', 'components': ['cmp.one'], 'owned_roots': [
            {'path': 'backend/internal/identity/register_user/', 'component': 'cmp.other'}]}
        with self.assertRaisesRegex(ValueError, 'component'):
            validate_feature_scopes([item], self.root)

    def test_real_registration_storage_maps_to_feature_and_component(self):
        root = Path(__file__).resolve().parents[3]
        registry = json.loads((root / 'tools/qa/local_features/features.json').read_text(encoding='utf-8'))
        catalog = load_curated_catalog(root, registry)
        result = analyze(['backend/internal/identity/register_user/postgres/repository.go'], catalog)
        self.assertIn('auth.registration', result['direct_features'])
        self.assertIn('cmp.backend.register_user', result['components'])
        self.assertEqual(result['unclassified_runtime_paths'], [])
