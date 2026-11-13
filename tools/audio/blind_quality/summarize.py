"""Summarize completed listener CSVs without publishing the operator key."""
import argparse
import csv
import json
from pathlib import Path

from .score import summarize


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--plan', type=Path, required=True)
    args = parser.parse_args()
    plan = json.loads((args.plan / 'operator-private.json').read_text(encoding='utf-8'))
    owners = {trial['trial']: trial['listener'] for trial in plan}
    listeners = sorted(set(owners.values()))
    votes = []
    for listener in listeners:
        with (args.plan / f'listener-{listener:02d}.csv').open(encoding='utf-8', newline='') as file:
            reader = csv.DictReader(file)
            if reader.fieldnames != ['trial', 'preferred', 'speech_defect']:
                raise ValueError('Invalid response sheet header')
            for row in reader:
                if owners.get(row['trial']) != listener:
                    raise ValueError('Response belongs to a different listener')
                votes.append(row)
    print(json.dumps(summarize(plan, votes), indent=2))


if __name__ == '__main__':
    main()
