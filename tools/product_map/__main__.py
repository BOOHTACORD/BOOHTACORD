"""Read-only prototype of the product-map projection; not a release gate."""
import argparse
import json
from pathlib import Path

from tools.product_map.projection.compare import compare
from tools.product_map.projection.importer import PLATFORMS, import_parity
from tools.product_map.projection.render import render_matrix
from tools.verify.client_parity.policy import validate


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('validate-parity')
    sub.add_parser('show')
    sub.add_parser('matrix')
    comparison = sub.add_parser('compare')
    comparison.add_argument('--platform', choices=PLATFORMS, action='append', required=True)
    comparison.add_argument('--scope', default='')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    path = root / 'tools/qa/local_features/features.json'
    catalog = json.loads(path.read_text(encoding='utf-8'))
    validate(catalog, root)
    data = import_parity(catalog)
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
