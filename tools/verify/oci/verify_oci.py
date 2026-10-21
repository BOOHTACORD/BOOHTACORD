#!/usr/bin/env python3
"""Verify a retained Buildx OCI archive before its local image is deployed."""

import hashlib
import json
import re
import sys
import tarfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(archive_path, revision, source_hash, expected_index_digest,
           docker_image_id=None, docker_rootfs_layers=None):
    require(re.fullmatch(r"[0-9a-f]{40}", revision), "invalid revision")
    require(re.fullmatch(r"[0-9a-f]{64}", source_hash), "invalid source archive hash")
    with tarfile.open(archive_path, "r") as archive:
        def checked_blob(descriptor, *, document=False):
            digest = descriptor.get("digest", "")
            require(re.fullmatch(r"sha256:[0-9a-f]{64}", digest), "invalid OCI digest")
            member = archive.extractfile("blobs/sha256/" + digest[7:])
            require(member is not None, "missing OCI blob " + digest)
            checksum = hashlib.sha256()
            size = 0
            chunks = []
            while chunk := member.read(1024 * 1024):
                checksum.update(chunk)
                size += len(chunk)
                if document:
                    require(size <= 32 * 1024 * 1024, "oversized OCI document")
                    chunks.append(chunk)
            require(checksum.hexdigest() == digest[7:], "OCI blob hash mismatch")
            require(size == descriptor.get("size"), "OCI blob size mismatch")
            return json.loads(b"".join(chunks)) if document else None

        def root_document():
            member = archive.extractfile("index.json")
            require(member is not None, "missing OCI index")
            return json.load(member)

        roots = root_document().get("manifests", [])
        require(len(roots) == 1, "expected one OCI index root")
        root = roots[0]
        require(root["digest"] == expected_index_digest, "OCI root digest differs from expected index digest")
        nested = checked_blob(root, document=True)
        require("manifests" in nested, "expected nested OCI index")
        manifests = nested["manifests"]
        runnable = [item for item in manifests if item.get("platform") == {"os": "linux", "architecture": "amd64"}]
        attested = [item for item in manifests if item.get("annotations", {}).get("vnd.docker.reference.type") == "attestation-manifest"]
        require(len(runnable) == 1 and len(attested) == 1 and len(manifests) == 2, "expected runnable and attestation manifests")
        runtime = runnable[0]
        attest = attested[0]
        require(attest.get("platform") == {"os": "unknown", "architecture": "unknown"}, "invalid attestation platform")
        require(attest["annotations"].get("vnd.docker.reference.digest") == runtime["digest"], "attestation targets another image")
        runtime_doc = checked_blob(runtime, document=True)
        config = checked_blob(runtime_doc["config"], document=True)
        config_digest = runtime_doc["config"]["digest"]
        require(re.fullmatch(r"sha256:[0-9a-f]{64}", config_digest), "invalid image config digest")
        if docker_image_id is not None:
            require(docker_image_id == config_digest, "loaded Docker image ID differs from verified OCI config")
        diff_ids = config.get("rootfs", {}).get("diff_ids")
        require(isinstance(diff_ids, list) and len(diff_ids) == len(runtime_doc["layers"])
                and all(isinstance(value, str) and re.fullmatch(r"sha256:[0-9a-f]{64}", value)
                        for value in diff_ids), "invalid image root filesystem")
        if docker_rootfs_layers is not None:
            require(docker_rootfs_layers == diff_ids,
                    "loaded Docker image layers differ from verified OCI config")
        labels = config.get("config", {}).get("Labels", {})
        require(labels.get("org.opencontainers.image.revision") == revision, "image revision label differs")
        require(labels.get("org.voice-platform.source-archive-sha256") == source_hash, "image source hash differs")
        for layer in runtime_doc["layers"]:
            checked_blob(layer)
        attestation_doc = checked_blob(attest, document=True)
        checked_blob(attestation_doc["config"])
        predicates = set()
        for layer in attestation_doc["layers"]:
            require(layer.get("mediaType") == "application/vnd.in-toto+json", "unexpected attestation layer")
            statement = checked_blob(layer, document=True)
            subjects = statement.get("subject", [])
            require(len(subjects) >= 1, "attestation has no subject")
            require(all(item.get("digest", {}).get("sha256") == runtime["digest"][7:] for item in subjects), "attestation subject differs")
            predicates.add(statement.get("predicateType"))
        require("https://spdx.dev/Document" in predicates, "SBOM attestation absent")
        require("https://slsa.dev/provenance/v0.2" in predicates, "provenance attestation absent")
        return {"index_digest": expected_index_digest, "manifest_digest": runtime["digest"], "image_id": config_digest,
                "revision": revision, "source_archive_sha256": source_hash,
                "attestation_predicates": sorted(predicates)}


if __name__ == "__main__":
    try:
        print(json.dumps(verify(*sys.argv[1:5]), sort_keys=True))
    except (ValueError, KeyError, OSError, tarfile.TarError, json.JSONDecodeError) as error:
        print(f"QA-11 OCI verification failed: {error}", file=sys.stderr)
        sys.exit(1)
