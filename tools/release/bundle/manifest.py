"""Dependency-free enforcement of release-manifest.schema.json on install hosts."""
import re

FILES = {"api.oci.tar", "web.oci.tar", "runtime.tar.gz", "checks.json"}
WORKER = 'join-sound-processor'
PREDICATES = {"https://spdx.dev/Document", "https://slsa.dev/provenance/v0.2"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def hex_value(value, length):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{%d}" % length, value)


def validate(manifest):
    try:
        _validate(manifest)
    except (KeyError, TypeError, AttributeError) as error:
        raise ValueError("Incomplete release manifest") from error


def _validate(m):
    require(set(m) == {"schema_version", "release_id", "source_revision", "source_archive_sha256",
                      "platform", "components", "files", "compatibility"}, "Unexpected manifest fields")
    require(m["schema_version"] == 1 and type(m["schema_version"]) is int, "Unsupported manifest schema")
    require(hex_value(m["source_revision"], 40), "Full source SHA is required")
    require(m["release_id"] == m["source_revision"], "Release ID must equal the immutable source SHA")
    require(hex_value(m["source_archive_sha256"], 64), "Invalid source archive checksum")
    require(m["platform"] == "linux/amd64", "Unsupported release platform")
    components = set(m['components'])
    require(components in ({'api', 'web'}, {'api', 'web', WORKER}), "Unexpected server components")
    for service, component in m["components"].items():
        require(set(component) == {"archive", "index_digest", "manifest_digest", "attestation_predicates"}, "Invalid component fields")
        require(component["archive"] == service + ".oci.tar", "Invalid component archive")
        for name in ("index_digest", "manifest_digest"):
            require(re.fullmatch(r"sha256:[0-9a-f]{64}", component[name]), "Invalid OCI digest")
        require(set(component["attestation_predicates"]) >= PREDICATES, "SBOM/provenance missing")
    expected = FILES | ({WORKER + '.oci.tar'} if WORKER in components else set())
    require(set(m["files"]) == expected, "Release must contain the exact approved payload files")
    for entry in m["files"].values():
        require(set(entry) == {"sha256", "bytes"} and hex_value(entry["sha256"], 64), "Invalid file checksum")
        require(type(entry["bytes"]) is int and 0 < entry["bytes"] <= 2_000_000_000, "Invalid payload size")
    compatibility = m["compatibility"]
    require(set(compatibility) == {"migrations", "backend_tree", "contracts_sha256", "topology_sha256"}, "Invalid compatibility fields")
    require(hex_value(compatibility["backend_tree"], 40), "Invalid backend tree identity")
    for name in ("contracts_sha256", "topology_sha256"):
        require(hex_value(compatibility[name], 64), "Invalid compatibility checksum")
    require(bool(compatibility["migrations"]), "Migration inventory is required")
    for name, digest in compatibility["migrations"].items():
        require(re.fullmatch(r"[0-9]{4}_[a-z0-9_]+\.sql", name), "Invalid migration name")
        require(hex_value(digest, 64), "Invalid migration checksum")
