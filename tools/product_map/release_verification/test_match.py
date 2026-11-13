import copy
import unittest

from tools.product_map.release_verification.match import match_live_release


def fixture():
    sha, digest = 'a' * 40, 'b' * 64
    evidence = {'status': 'MATCHED_UNVERIFIED', 'published': 'UNKNOWN',
                'source_revision': sha, 'manifest_sha256': digest, 'github_release_id': 17,
                'asset_inventory': {'artifact-manifest.json': {'bytes': 100, 'sha256': digest}}}
    release = {'id': 17, 'tag_name': 'windows-v1.0.52', 'target_commitish': sha,
               'draft': False, 'prerelease': False, 'published_at': '2026-01-01T00:00:00Z',
               'assets': [{'name': 'artifact-manifest.json', 'state': 'uploaded',
                           'size': 100, 'digest': 'sha256:' + digest}]}
    return evidence, release, sha


class ReleaseMatchTests(unittest.TestCase):
    def test_matching_release_does_not_by_itself_verify_provenance(self):
        evidence, release, commit = fixture()
        result = match_live_release(evidence, 'windows-v1.0.52', release, commit)
        self.assertEqual(result['status'], 'LIVE_RELEASE_MATCHED_UNVERIFIED')
        self.assertEqual(result['published'], 'UNKNOWN')

    def test_rejects_wrong_release_tag_commit_and_incomplete_assets(self):
        for key, value in [('id', 18), ('tag_name', 'windows-v1.0.53'),
                           ('draft', True), ('prerelease', True), ('published_at', None),
                           ('target_commitish', 'b' * 40), ('assets', [])]:
            evidence, release, commit = fixture()
            release[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                match_live_release(evidence, 'windows-v1.0.52', release, commit)
        evidence, release, _ = fixture()
        with self.assertRaises(ValueError):
            match_live_release(evidence, 'windows-v1.0.52', release, 'c' * 40)

    def test_rejects_duplicate_unknown_modified_or_unuploaded_asset(self):
        for mutation in ('duplicate', 'name', 'digest', 'size', 'state'):
            evidence, release, commit = fixture()
            asset = release['assets'][0]
            if mutation == 'duplicate': release['assets'].append(copy.deepcopy(asset))
            if mutation == 'name': asset['name'] = 'other.zip'
            if mutation == 'digest': asset['digest'] = 'sha256:' + 'c' * 64
            if mutation == 'size': asset['size'] = 101
            if mutation == 'state': asset['state'] = 'starter'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                match_live_release(evidence, 'windows-v1.0.52', release, commit)
