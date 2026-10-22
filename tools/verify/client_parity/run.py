import argparse
import json
import subprocess
from .policy import ROOT, validate
from tools.qa.local_features.policy import covered_features, changed_paths


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', default='')
    args = parser.parse_args()
    path = 'tools/qa/local_features/features.json'
    catalog = json.loads((ROOT/path).read_text())
    validate(catalog)
    if args.base:
        previous = json.loads(subprocess.check_output(['git', 'show', args.base+':'+path], cwd=ROOT, text=True))
        changed = changed_paths(ROOT, args.base)
        product = [p for p in changed if p.startswith(('clients/web/src/', 'clients/flutter/lib/'))]
        for feature in covered_features(product, catalog):
            review = catalog[feature]['parity_review']
            if review == previous.get(feature, {}).get('parity_review'):
                raise ValueError('Record Web/iOS/Android regression decision for changed common feature: '+feature)
    print('PASS: unique parity scenarios, client paths, platform decisions and honest evidence states')

if __name__ == '__main__': main()
