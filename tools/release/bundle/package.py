"""Create the immutable payload manifest and sign it with the protected CI key."""
import json
import tarfile
from contextlib import nullcontext
from .files import check_files, check_receipt, sha256
from .manifest import FILES, validate
from .signature import sign


def package(root, revision, source_hash, receipts, compatibility, checks, private_key, *, measure=None):
    measure=measure or (lambda _:nullcontext())
    with measure('manifest'):
        check_receipt(checks, revision)
        (root / "checks.json").write_text(json.dumps(checks, sort_keys=True) + "\n", encoding="utf-8")
        manifest = {"schema_version": 1, "release_id": revision, "source_revision": revision,
                  "source_archive_sha256": source_hash, "platform": "linux/amd64",
                  "components": {}, "compatibility": compatibility,
                  "files": {name: {"sha256": sha256(root / name), "bytes": (root / name).stat().st_size} for name in sorted(FILES)}}
        for service, receipt in receipts.items():
          manifest["components"][service] = {"archive": service + ".oci.tar", **{
              key: receipt[key] for key in ("index_digest", "manifest_digest", "attestation_predicates")}}
        validate(manifest)
        check_files(root, manifest)
        document = root / "manifest.json"
        document.write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    with measure('sign'):sign(document, private_key)
    destination = root.parent / (revision + ".release.tar.gz")
    with measure('package'):
        with tarfile.open(destination, "x:gz", compresslevel=1) as archive:
          for name in sorted(FILES | {"manifest.json", "manifest.json.sig"}):
              archive.add(root / name, arcname=name, recursive=False)
        destination.with_suffix(destination.suffix + ".sha256").write_text(
          sha256(destination) + "  " + destination.name + "\n", encoding="utf-8")
    return destination
