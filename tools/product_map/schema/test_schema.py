import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from tools.product_map.release import test_snapshot
from tools.product_map.release.snapshot import create_snapshot
from tools.product_map.release.build import build_verified_snapshot
from tools.release.native_contract import test_assets
from tools.product_map.catalog.curated import load_curated_catalog

ROOT = Path(__file__).resolve().parents[3]
SCHEMA_ROOT = ROOT / 'product-map/schema'


def validators():
    files = list(SCHEMA_ROOT.glob('*.schema.json'))
    schemas = [json.loads(path.read_text(encoding='utf-8')) for path in files]
    for schema in schemas:
        Draft202012Validator.check_schema(schema)
    registry = Registry().with_resources((schema['$id'], Resource.from_contents(schema)) for schema in schemas)
    return {schema['$id'].rsplit('/', 1)[-1]: Draft202012Validator(schema, registry=registry)
            for schema in schemas}


class SchemaTests(unittest.TestCase):
    def test_duplicate_catalog_keys_fail_before_schema_projection(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / 'product-map/features/example/core.yaml'
            path.parent.mkdir(parents=True)
            path.write_text('{"features":[],"features":[],"components":[]}', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'duplicate'):
                load_curated_catalog(root, {})

    def test_all_existing_catalog_documents_match_schema(self):
        schema = validators()['catalog.schema.json']
        files = list((ROOT / 'product-map/features').glob('*/*.yaml'))
        self.assertTrue(files)
        for path in files:
            with self.subTest(path=path.name):
                schema.validate(json.loads(path.read_text(encoding='utf-8')))

    def test_missing_platform_and_ambiguous_component_are_rejected(self):
        schemas = validators()
        data = json.loads((ROOT / 'product-map/features/auth/core.yaml').read_text(encoding='utf-8'))
        broken = copy.deepcopy(data)
        del broken['features'][0]['platforms']['windows']
        self.assertFalse(schemas['catalog.schema.json'].is_valid(broken))
        broken = copy.deepcopy(data)
        broken['components'][0]['source'] = {'parity_id': 'auth.session', 'platform': 'web'}
        self.assertFalse(schemas['catalog.schema.json'].is_valid(broken))

    def test_native_snapshot_schema_rejects_fake_runtime_or_missing_provenance(self):
        schemas = validators()
        fixture = test_snapshot.SnapshotTests('test_snapshot_keeps_release_and_runtime_unproven')
        fixture.setUp()
        snapshot = create_snapshot(fixture.catalog, fixture.raw, fixture.sha, 'windows', fixture.digest)
        self.assertTrue(schemas['release-snapshot.schema.json'].is_valid(snapshot))
        snapshot['runtime'] = 'PASS'
        self.assertFalse(schemas['release-snapshot.schema.json'].is_valid(snapshot))
        snapshot['runtime'] = 'NOT_VERIFIED'
        snapshot['build_provenance'] = 'VERIFIED_ASSET_CONTRACT'
        self.assertFalse(schemas['release-snapshot.schema.json'].is_valid(snapshot))

    def test_verified_asset_gate_snapshot_matches_schema(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory, context = test_assets.fixture(Path(tmp), 'windows')
            context['execution'] = {'run_id': '123', 'run_attempt': '1'}
            with patch('tools.product_map.release.build.preflight', return_value=context), \
                 patch('tools.product_map.release.build.require_exact_source'):
                snapshot = build_verified_snapshot(ROOT, 'windows', directory / 'artifact-manifest.json')
            self.assertTrue(validators()['release-snapshot.schema.json'].is_valid(snapshot))
