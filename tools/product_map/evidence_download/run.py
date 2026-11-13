"""Inspect native workflow evidence without treating a match as publication."""
from tools.product_map.release.archive import read_native_evidence
from tools.product_map.release.github_api import fetch_candidate
from .transport import download_artifact


def inspect_native_run(platform, run_id, tag, token=None):
    candidate = fetch_candidate(platform, run_id, tag, token)
    return read_native_evidence(download_artifact(candidate, token), candidate)
