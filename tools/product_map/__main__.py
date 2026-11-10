"""Read-only prototype of the product-map projection; not a release gate."""
import argparse
import json
import os
from pathlib import Path

from tools.product_map.projection.compare import compare
from tools.product_map.projection.importer import PLATFORMS, import_parity
from tools.product_map.projection.render import render_matrix
from tools.product_map.catalog.enrich import enrich_projection
from tools.product_map.catalog.curated import load_curated_catalog
from tools.product_map.viewer.document import build_document, write_document
from tools.verify.client_parity.policy import validate


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('validate-parity')
    sub.add_parser('show')
    sub.add_parser('matrix')
    impact = sub.add_parser('impact')
    impact.add_argument('--base', required=True, help='exact base commit SHA')
    transition = sub.add_parser('check-transition')
    transition.add_argument('--base', required=True, help='exact base commit SHA')
    generate = sub.add_parser('generate')
    generate.add_argument('--check', action='store_true')
    snapshot = sub.add_parser('release-snapshot')
    snapshot.add_argument('--platform', choices=('windows', 'macos', 'android'), required=True)
    snapshot.add_argument('--manifest', type=Path, required=True)
    publication = sub.add_parser('match-publication')
    publication.add_argument('--snapshot', type=Path, required=True)
    publication.add_argument('--contract', type=Path, required=True)
    publication.add_argument('--receipt', type=Path, required=True)
    candidate = sub.add_parser('native-release-candidate')
    candidate.add_argument('--platform', choices=('windows', 'macos', 'android'), required=True)
    candidate.add_argument('--run-id', type=int, required=True)
    candidate.add_argument('--tag', required=True)
    comparison = sub.add_parser('compare')
    comparison.add_argument('--platform', choices=PLATFORMS, action='append', required=True)
    comparison.add_argument('--scope', default='')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if args.command == 'native-release-candidate':
        from tools.product_map.release.github_api import fetch_candidate
        print(json.dumps(fetch_candidate(args.platform, args.run_id, args.tag,
                                         os.environ.get('GITHUB_TOKEN')), indent=2, sort_keys=True))
        return
    if args.command == 'match-publication':
        from tools.product_map.release.publication import load_record, match_publication
        print(json.dumps(match_publication(load_record(args.snapshot), load_record(args.contract),
                                           load_record(args.receipt)), indent=2, sort_keys=True))
        return
    if args.command == 'release-snapshot':
        from tools.product_map.release.cli import run
        run(root, args.platform, args.manifest)
        return
    path = root / 'tools/qa/local_features/features.json'
    catalog = json.loads(path.read_text(encoding='utf-8'))
    validate(catalog, root)
    curated = load_curated_catalog(root, catalog)
    if args.command == 'check-transition':
        from tools.product_map.catalog.history import read_previous_catalog
        from tools.product_map.catalog.transition import validate_transition
        previous = read_previous_catalog(root, args.base)
        validate_transition(previous, curated)
        print(f'Catalog transition valid: {len(previous["features"])} prior feature IDs, '
              f'{len(previous["components"])} prior component IDs.')
        return
    if args.command == 'impact':
        from tools.product_map.impact.analyze import analyze
        from tools.product_map.impact.changes import changed_paths
        print(json.dumps(analyze(changed_paths(root, args.base), curated),
                         ensure_ascii=False, indent=2, sort_keys=True))
        return
    data = import_parity(catalog)
    data = enrich_projection(data, curated)
    if args.command == 'generate':
        target = root / 'docs/product-map/generated/index.html'
        if not write_document(target, build_document(data), check=args.check):
            parser.exit(1, 'Generated product map is missing or stale; run generate.\n')
        print('Product map is current.' if args.check else f'Generated {target}')
        return
    if args.command == 'validate-parity':
        print(f'PASS parity projection: {len(catalog)} groups, {len(data)} IDs; '
              'full product-map validation is NOT IMPLEMENTED')
        return
    if args.command == 'matrix':
        print(render_matrix(data), end='')
        return
    if args.command == 'compare':
        if len(args.platform) != 2:
            parser.error('compare requires exactly two --platform values')
        data = compare([x for x in data if x['id'].startswith(args.scope)],
                       *args.platform)
    print(json.dumps(data, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
