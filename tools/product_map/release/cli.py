"""Write the product-map sidecar outside the immutable native package."""
import json

from .build import build_verified_snapshot


def run(root, platform, manifest):
    result = build_verified_snapshot(root, platform, manifest)
    destination = root / '.out/native-release' / platform / 'feature-snapshot.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(result, sort_keys=True, indent=2) + '\n',
                           encoding='utf-8', newline='\n')
    print(f'Built source-bound feature sidecar: {destination}; publication remains UNKNOWN')
