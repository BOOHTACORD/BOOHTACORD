"""Create a local sidecar only after the existing native asset gate succeeds."""
import json
from pathlib import Path

from tools.product_map.catalog.curated import load_curated_catalog
from tools.product_map.release.snapshot import create_snapshot
from tools.product_map.release.source import require_exact_source
from tools.release.native_contract.assets import validate as validate_assets
from tools.release.native_contract.source import preflight


def build_verified_snapshot(root, platform, manifest_path):
    manifest_path = Path(manifest_path)
    if manifest_path.name != 'artifact-manifest.json' or manifest_path.is_symlink():
        raise ValueError('native artifact-manifest.json required')
    context = preflight(platform)
    require_exact_source(root, context['source_revision'])
    contract = validate_assets(manifest_path.parent, context)
    raw = manifest_path.read_bytes()
    registry = json.loads((root / 'tools/qa/local_features/features.json')
                          .read_text(encoding='utf-8'))
    catalog = load_curated_catalog(root, registry)
    value = create_snapshot(catalog, raw, context['source_revision'], platform,
                            contract['manifest_sha256'])
    require_exact_source(root, context['source_revision'])
    value['build_provenance'] = 'VERIFIED_ASSET_CONTRACT'
    value['execution'] = context['execution']
    return value
