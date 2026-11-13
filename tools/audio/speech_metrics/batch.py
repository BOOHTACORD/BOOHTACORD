"""Aggregate offline diagnostic scores without emitting paths or speech."""
import argparse
import json
import re
import statistics
from pathlib import Path

from .score import read_checked, score_pair, verified_versions


def summarize(manifest):
    versions = verified_versions()
    pairs = manifest.get('pairs') if isinstance(manifest, dict) else None
    if not isinstance(pairs, list) or not 1 <= len(pairs) <= 1000:
        raise ValueError('invalid pair list')
    groups = {}
    for pair in pairs:
        if (not isinstance(pair, dict) or not isinstance(pair.get('engine'), str) or
                not re.fullmatch(r'[a-z0-9_-]{1,32}', pair['engine'])):
            raise ValueError('invalid engine')
        keys = ('reference', 'candidate', 'referenceSha256', 'candidateSha256', 'lagSamples')
        if any(key not in pair for key in keys) or any(
            not re.fullmatch(r'[a-f0-9]{64}', str(pair[key])) for key in ('referenceSha256', 'candidateSha256')
        ) or any(not isinstance(pair[key], str) or not pair[key] for key in ('reference', 'candidate')):
            raise ValueError('invalid pair')
        scores = score_pair(read_checked(pair['reference'], pair['referenceSha256']),
                            read_checked(pair['candidate'], pair['candidateSha256']), pair['lagSamples'])
        groups.setdefault(pair['engine'], []).append((scores, pair['referenceSha256'], pair['candidateSha256'], pair['lagSamples']))
    result = {}
    for engine, rows in groups.items():
        lags = sorted({row[3] for row in rows})
        item = {'count': len(rows), 'lagSamples': lags[0] if len(lags) == 1 else lags,
                'inputHashes': [row[1] for row in rows], 'outputHashes': [row[2] for row in rows]}
        for metric in ('stoi', 'estoi'):
            values = [row[0][metric] for row in rows]
            item[metric] = [round(float(fn(values)), 6) for fn in (min, statistics.median, max)]
        result[engine] = item
    return {'status': 'RESEARCH_ONLY', 'engines': result,
            'versions': versions,
            'limitations': ['Assumes clean reference; listening and device acceptance NOT_RUN']}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--manifest', type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.manifest.stat().st_size > 1_000_000:
            raise ValueError('manifest too large')
        manifest = args.manifest.read_text(encoding='utf-8')
    except OSError:
        raise ValueError('manifest unavailable') from None
    print(json.dumps(summarize(json.loads(manifest))))


if __name__ == '__main__':
    main()
