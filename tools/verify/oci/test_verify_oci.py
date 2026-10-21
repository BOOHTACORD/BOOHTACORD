import hashlib
import io
import json
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path


REVISION = "b" * 40
SOURCE_HASH = "a" * 64


def fixture(path, *, bad_subject=False, include_config=False):
    blobs = {}

    def add(value):
        data = json.dumps(value, separators=(",", ":")).encode()
        digest = "sha256:" + hashlib.sha256(data).hexdigest()
        blobs[digest] = data
        return {"digest": digest, "size": len(data)}

    config = add({"config": {"Labels": {
        "org.opencontainers.image.revision": REVISION,
        "org.voice-platform.source-archive-sha256": SOURCE_HASH,
    }}, "rootfs": {"type": "layers", "diff_ids": []}})
    runnable = add({"config": config, "layers": []})
    subject = "sha256:" + ("0" * 64) if bad_subject else runnable["digest"]
    layers = []
    for predicate in ("https://spdx.dev/Document", "https://slsa.dev/provenance/v0.2"):
        statement = add({"predicateType": predicate, "subject": [{"digest": {"sha256": subject[7:]}}]})
        layers.append({**statement, "mediaType": "application/vnd.in-toto+json"})
    attestation = add({"config": config, "layers": layers})
    nested = add({"manifests": [
        {**runnable, "platform": {"os": "linux", "architecture": "amd64"}},
        {**attestation, "platform": {"os": "unknown", "architecture": "unknown"},
         "annotations": {"vnd.docker.reference.type": "attestation-manifest",
                         "vnd.docker.reference.digest": runnable["digest"]}},
    ]})
    root = {"manifests": [nested]}
    with tarfile.open(path, "w") as archive:
        for name, data in [("index.json", json.dumps(root).encode())] + [
            ("blobs/sha256/" + digest[7:], data) for digest, data in blobs.items()
        ]:
            member = tarfile.TarInfo(name)
            member.size = len(data)
            archive.addfile(member, io.BytesIO(data))
    return (nested["digest"], config["digest"]) if include_config else nested["digest"]


class VerifyOciTests(unittest.TestCase):
    def run_verifier(self, archive, image_id):
        return subprocess.run([
            sys.executable, str(Path(__file__).with_name("verify_oci.py")), str(archive),
            REVISION, SOURCE_HASH, image_id,
        ], capture_output=True, text=True)

    def test_valid_nested_index_with_two_attestations(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "image.oci.tar"
            index_digest, image_id = fixture(path, include_config=True)
            result = self.run_verifier(path, index_digest)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)["index_digest"], index_digest)
            self.assertEqual(json.loads(result.stdout)["image_id"], image_id)

    def test_loaded_docker_id_is_checked_against_the_verified_image_config(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "image.oci.tar"
            index_digest, image_id = fixture(path, include_config=True)
            from tools.verify.oci.verify_oci import verify
            self.assertEqual(image_id, verify(path, REVISION, SOURCE_HASH, index_digest,
                                              docker_image_id=image_id, docker_rootfs_layers=[])["image_id"])
            with self.assertRaises(ValueError):
                verify(path, REVISION, SOURCE_HASH, index_digest, docker_image_id="sha256:" + "f" * 64)
            with self.assertRaises(ValueError):
                verify(path, REVISION, SOURCE_HASH, index_digest, docker_image_id=image_id,
                       docker_rootfs_layers=["sha256:" + "f" * 64])

    def test_rejects_wrong_subject_and_loaded_id(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "image.oci.tar"
            index_digest = fixture(path, bad_subject=True)
            self.assertNotEqual(self.run_verifier(path, index_digest).returncode, 0)
            index_digest = fixture(path)
            self.assertNotEqual(self.run_verifier(path, "sha256:" + "f" * 64).returncode, 0)


if __name__ == "__main__":
    unittest.main()
