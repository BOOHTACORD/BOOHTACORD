"""Create bounded synthetic feature rows for local viewer measurements."""
import copy
import argparse
import json
from pathlib import Path


def synthetic_features(sample, count):
    if type(count) is not int or not 1 <= count <= 10000:
        raise ValueError('synthetic feature count must be between 1 and 10000')
    result = []
    for index in range(count):
        feature = copy.deepcopy(sample)
        feature['id'] = f'synthetic.feature_{index:05}'
        feature['description'] = f'Synthetic feature {index:05}'
        result.append(feature)
    return result


def main():
    from tools.product_map.catalog.curated import load_curated_catalog
    from tools.product_map.catalog.enrich import enrich_projection
    from tools.product_map.projection.importer import import_parity
    from tools.product_map.viewer.document import build_document
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--count', type=int, default=1001)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    registry = json.loads((root / 'tools/qa/local_features/features.json').read_text(encoding='utf-8'))
    features = enrich_projection(import_parity(registry), load_curated_catalog(root, registry))
    args.output.write_text(build_document(synthetic_features(features[0], args.count)), encoding='utf-8')


if __name__ == '__main__':
    main()
