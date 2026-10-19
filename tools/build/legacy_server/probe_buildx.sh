#!/usr/bin/env bash
set -euo pipefail

incoming="${1:-}"
[[ "$incoming" =~ ^/tmp/voice-platform-qa11-buildx-[0-9a-f]{40}-[0-9a-f]{16}$ ]] || {
  echo 'Invalid temporary Buildx path' >&2
  exit 1
}
expected=9447199cdb435f25880548343c128a4b6650e8891ee598905d8d29d39a8e359b
config=''
probe_compose=''
probe_image="voice-platform-qa11-probe:${incoming##*-}"
cleanup() {
  result=$?
  failed=0
  if [[ -n "$probe_compose" ]]; then
    sudo -n docker compose -p "$probe_project" -f "$probe_compose" down --remove-orphans >/dev/null 2>&1 || failed=1
  fi
  # An unsuccessful build may not have loaded an image. Never remove an
  # unrelated object or perform a global cache/volume prune.
  loaded="$(sudo -n docker image ls --filter "reference=$probe_image" --format '{{.Repository}}:{{.Tag}}')" || failed=1
  if [[ "$loaded" == "$probe_image" ]]; then
    sudo -n docker image rm -- "$probe_image" >/dev/null 2>&1 || failed=1
  elif [[ -n "$loaded" ]]; then
    failed=1
  fi
  if [[ "$config" == /tmp/voice-platform-qa11-config.* ]]; then
    sudo -n rm -rf -- "$config" || failed=1
  fi
  rm -f -- "$incoming" || failed=1
  if (( failed )); then echo 'Operator probe cleanup failed' >&2; exit 1; fi
  if (( result == 0 )); then echo 'operator_probe_cleanup=PASS'; fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Share the installer/resume/rollback host lock as well as the Actions writer queue.
[[ -d /opt/voice-platform-releases ]]
exec 9>/opt/voice-platform-releases/.install.lock
flock --exclusive --wait 30 9
actual="$(sha256sum "$incoming" | awk '{print $1}')"
[[ "$actual" == "$expected" ]] || { echo 'Buildx checksum differs' >&2; exit 1; }

config="$(sudo -n mktemp -d "/tmp/voice-platform-qa11-config.${incoming##*-}.XXXXXXXX")"
sudo -n install -d -m 0755 "$config/cli-plugins"
sudo -n install -m 0755 "$incoming" "$config/cli-plugins/docker-buildx"
sudo -n env DOCKER_CONFIG="$config" docker buildx version
sudo -n env DOCKER_CONFIG="$config" docker buildx ls

mountpoint="$(sudo -n docker volume inspect --format '{{.Mountpoint}}' voice-platform_attachments-data)"
[[ "$mountpoint" == /* ]] || { echo 'Attachment volume mountpoint is invalid' >&2; exit 1; }
available="$(sudo -n df -B1 --output=avail -- "$mountpoint" | awk 'NR == 2 { print $1 }')"
[[ "$available" =~ ^[0-9]+$ ]] || { echo 'Available bytes are invalid' >&2; exit 1; }
(( 10#$available > 9000000000 )) || { echo 'Insufficient space for the QA-11 probe' >&2; exit 1; }

sudo -n install -d -m 0755 "$config/context"
printf 'FROM scratch\nCOPY marker /marker\nCMD ["/marker"]\n' | sudo -n tee "$config/context/Dockerfile" >/dev/null
printf 'QA-11 build probe\n' | sudo -n tee "$config/context/marker" >/dev/null
if sudo -n env DOCKER_CONFIG="$config" docker buildx build \
  --platform linux/amd64 --sbom=true --provenance=mode=max \
  --output="type=oci,dest=$config/probe.oci.tar" \
  --metadata-file="$config/build-metadata.json" "$config/context"; then
  printf 'default_driver_oci_export=yes\n'
  sudo -n ls -l "$config/probe.oci.tar" "$config/build-metadata.json"
else
  printf 'default_driver_oci_export=no\n'
fi

if sudo -n env DOCKER_CONFIG="$config" docker buildx build \
  --platform linux/amd64 --sbom=true --provenance=mode=max \
  --output="type=oci,dest=$config/probe-dual.oci.tar" \
  --load --tag "$probe_image" "$config/context"; then
  printf 'default_driver_dual_export=yes\n'
  printf 'probe_image_id=%s\n' "$(sudo -n docker image inspect --format '{{.Id}}' "$probe_image")"
  sudo -n ls -l "$config/probe-dual.oci.tar"
  sudo -n python3 - "$config/probe-dual.oci.tar" "$config/oci-index-digest" <<'PY'
import hashlib, json, re, sys, tarfile
with tarfile.open(sys.argv[1], "r") as archive:
    def document(name):
        member = archive.extractfile(name)
        if member is None:
            raise ValueError(f"missing OCI entry: {name}")
        return json.load(member)
    def walk(descriptor):
        digest = descriptor["digest"]
        manifest = document(f"blobs/sha256/{digest.split(':', 1)[1]}")
        print("descriptor", digest, descriptor.get("platform"), descriptor.get("annotations"))
        if "manifests" in manifest:
            for child in manifest["manifests"]:
                walk(child)
            return
        print("config", manifest["config"]["digest"])
        for layer in manifest["layers"]:
            if layer["mediaType"] != "application/vnd.in-toto+json":
                continue
            statement = document(f"blobs/sha256/{layer['digest'].split(':', 1)[1]}")
            print("attestation", statement.get("predicateType"), statement.get("subject"))
    root = document("index.json")["manifests"]
    if len(root) != 1 or root[0]["mediaType"] != "application/vnd.oci.image.index.v1+json":
        raise ValueError("expected one OCI image index root descriptor")
    index_digest = root[0]["digest"]
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", index_digest):
        raise ValueError("invalid OCI image index digest")
    index_blob = archive.extractfile(f"blobs/sha256/{index_digest.removeprefix('sha256:')}").read()
    if hashlib.sha256(index_blob).hexdigest() != index_digest.removeprefix("sha256:") or len(index_blob) != root[0]["size"]:
        raise ValueError("OCI image index digest or size mismatch")
    print("oci_index_digest", index_digest)
    with open(sys.argv[2], "w", encoding="ascii") as output:
        output.write(index_digest)
    for descriptor in root:
        walk(descriptor)
PY
  index_digest="$(sudo -n cat "$config/oci-index-digest")"
  probe_ref="${probe_image%%:*}@$index_digest"
  if [[ "$(sudo -n docker image inspect --format '{{.Id}}' "$probe_ref" 2>/dev/null || true)" == "$index_digest" ]]; then
    printf 'local_digest_ref=yes\n'
  else
    printf 'local_digest_ref=no\n'
  fi
  probe_project="qa11${incoming##*-}"
  probe_project="${probe_project,,}"
  probe_compose="$config/probe-compose.yaml"
  printf 'services:\n  probe:\n    image: %s\n    pull_policy: never\n    network_mode: none\n' "$probe_ref" | sudo -n tee "$probe_compose" >/dev/null
  if sudo -n docker compose -p "$probe_project" -f "$probe_compose" create --no-build --pull never probe; then
    container="$(sudo -n docker compose -p "$probe_project" -f "$probe_compose" ps --all --quiet probe)"
    observed="$(sudo -n docker inspect --format '{{.Image}} {{.Config.Image}} {{.State.Running}}' "$container")"
    if [[ "$observed" == "$index_digest $probe_ref false" ]]; then
      printf 'compose_local_digest_ref=yes\n'
    else
      printf 'compose_local_digest_ref=no; observed=%s\n' "$observed"
    fi
  else
    printf 'compose_local_digest_ref=no\n'
  fi
else
  printf 'default_driver_dual_export=no\n'
fi
