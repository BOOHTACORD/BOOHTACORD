"""Print scoped ownership coverage for the exact clean catalog at HEAD."""
import json
import subprocess
from pathlib import Path

from tools.product_map.catalog.curated import load_curated_catalog
from tools.verify.client_parity.policy import validate
from .coverage import coverage_report
from .git_tree import tracked_files


def report(root):
    def git(*args):
        return subprocess.run(['git', *args], cwd=root, check=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
    dirty = git('status', '--porcelain', '--untracked-files=all', '--',
                'product-map/features/', 'tools/qa/local_features/features.json')
    if dirty:
        raise ValueError('catalog or parity registry differs from HEAD')
    sha = git('rev-parse', '--verify', 'HEAD^{commit}').decode('ascii').strip()
    registry = json.loads((root / 'tools/qa/local_features/features.json').read_text(encoding='utf-8'))
    validate(registry, root)
    catalog = load_curated_catalog(root, registry)
    return {'source_revision': sha, **coverage_report(tracked_files(root, sha), catalog)}


def main():
    root = Path(__file__).resolve().parents[3]
    print(json.dumps(report(root), ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
