import argparse
import json
from pathlib import Path
from .collect import collect

parser = argparse.ArgumentParser(description='Collect source-bound Cargo notices')
parser.add_argument('--metadata', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
report = collect(json.loads(args.metadata.read_text(encoding='utf-8')), args.output)
print(json.dumps({key: report[key] for key in ('packages', 'noticeFiles', 'unresolved')}))
