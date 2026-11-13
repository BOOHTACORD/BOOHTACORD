"""Fail PRs that add runtime paths without a catalogued component."""
import argparse
import json
import subprocess
from pathlib import Path

from tools.product_map.catalog.curated import load_curated_catalog
from tools.verify.client_parity.policy import validate
from .git_tree import tracked_files
from .new_paths import classify_new_paths


def run(root, base):
    registry = json.loads((root / 'tools/qa/local_features/features.json').read_text(encoding='utf-8'))
    validate(registry, root)
    catalog = load_curated_catalog(root, registry)
    head = subprocess.run(['git', 'rev-parse', '--verify', 'HEAD^{commit}'], cwd=root, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.decode('ascii').strip()
    previous, current = tracked_files(root, base), tracked_files(root, head)
    return classify_new_paths(previous, current, catalog)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', required=True, help='exact base commit SHA')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    unknown = run(root, args.base)
    if unknown:
        print('New runtime files need an explicit product-map component path:')
        for path in unknown:
            print(' - ' + path)
        parser.exit(1, 'Map each path to an existing or new component and link its feature.\n')
    print('No new unmapped runtime paths; pre-existing baseline remains unclassified.')


if __name__ == '__main__':
    main()
