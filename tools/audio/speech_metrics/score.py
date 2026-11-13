"""Offline diagnostics for explicitly licensed reference audio, never calls."""
import argparse
import hashlib
import importlib.metadata
import json
import warnings
from pathlib import Path

import numpy as np
from pystoi import stoi

EXPECTED_VERSIONS = {'numpy': '2.3.4', 'scipy': '1.16.2', 'pystoi': '0.4.1'}


def verified_versions():
    actual = {name: importlib.metadata.version(name) for name in EXPECTED_VERSIONS}
    if actual != EXPECTED_VERSIONS:
        raise ValueError('unexpected metric dependency versions')
    return actual


def score_pair(reference, candidate, lag):
    if isinstance(lag, bool) or not isinstance(lag, int) or lag < 0 or lag > 48000:
        raise ValueError('invalid alignment')
    reference = np.asarray(reference, dtype=np.float64)
    candidate = np.asarray(candidate, dtype=np.float64)
    if reference.ndim != 1 or candidate.ndim != 1 or reference.size < 48000:
        raise ValueError('invalid reference length')
    if candidate.size < reference.size + lag:
        raise ValueError('candidate is too short')
    candidate = candidate[lag:lag + reference.size]
    if not np.isfinite(reference).all() or not np.isfinite(candidate).all():
        raise ValueError('nonfinite audio')
    if np.max(np.abs(reference)) < 1e-8:
        raise ValueError('silent reference')
    with warnings.catch_warnings():
        warnings.simplefilter('error', RuntimeWarning)
        values = [float(stoi(reference, candidate, 48000, extended=flag)) for flag in (False, True)]
    if not np.isfinite(values).all():
        raise ValueError('nonfinite score')
    return {'stoi': values[0], 'estoi': values[1]}


def read_checked(path, expected):
    path = Path(path)
    try:
        if path.stat().st_size > 100_000_000:
            raise ValueError('input too large')
        data = path.read_bytes()
    except OSError:
        raise ValueError('input unavailable') from None
    if not data or len(data) % 4 or hashlib.sha256(data).hexdigest() != expected:
        raise ValueError('invalid input or checksum')
    return np.frombuffer(data, dtype='<f4')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--reference', required=True)
    parser.add_argument('--reference-sha256', required=True)
    parser.add_argument('--candidate', required=True)
    parser.add_argument('--candidate-sha256', required=True)
    parser.add_argument('--lag-samples', type=int, required=True)
    args = parser.parse_args()
    versions = verified_versions()
    scores = score_pair(read_checked(args.reference, args.reference_sha256),
                        read_checked(args.candidate, args.candidate_sha256), args.lag_samples)
    print(json.dumps({'status': 'RESEARCH_ONLY', 'scores': scores, 'lagSamples': args.lag_samples,
                      'referenceSha256': args.reference_sha256, 'candidateSha256': args.candidate_sha256,
                      'versions': versions,
                      'limitations': ['Assumes clean reference; no listening or device acceptance']}))


if __name__ == '__main__':
    main()
