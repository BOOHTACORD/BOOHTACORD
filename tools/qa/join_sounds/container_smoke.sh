#!/usr/bin/env bash
set -euo pipefail
image="${1:?worker image required}"
owner="qa-join-$(python3 -c 'import secrets;print(secrets.token_hex(6))')"
network="$owner-network"
worker="$owner-worker"
docker network create --internal "$network" >/dev/null
cleanup() {
  docker logs "$worker" >&2 || true
  docker stop "$worker" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
}
trap cleanup EXIT
docker run --detach --rm --name "$worker" --network "$network" --user 65532:65532 \
  --read-only --cap-drop ALL --security-opt no-new-privileges:true --cpus 1 \
  --memory 256m --pids-limit 64 --tmpfs /tmp:size=16m,mode=1777,noexec,nosuid,nodev "$image" >/dev/null
python3 - <<'PY' | docker run --rm -i --network "$network" --read-only \
  --tmpfs /tmp:size=16m,mode=1777,noexec,nosuid,nodev --entrypoint sh curlimages/curl:8.17.0@sha256:935d9100e9ba842cdb060de42472c7ca90cfe9a7c96e4dacb55e79e560b3ff40 \
  -ec 'cat >/tmp/test.wav; curl --fail --max-time 12 --silent --show-error --data-binary @/tmp/test.wav "http://$1:8090/normalize" --output /tmp/result.mp3; size=$(wc -c </tmp/result.mp3); test "$size" -gt 0; test "$size" -le 262144; echo "ISOLATED_WORKER_PASS bytes=$size"' sh "$worker"
import io, wave, math, struct, sys
body = io.BytesIO()
with wave.open(body, 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(48000)
    output.writeframes(b''.join(struct.pack('<h', int(math.sin(i*2*math.pi*440/48000)*30000)) for i in range(48000)))
sys.stdout.buffer.write(body.getvalue())
PY
test "$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}} {{.HostConfig.Memory}} {{.HostConfig.PidsLimit}} {{.Config.User}}' "$worker")" = 'true 268435456 64 65532:65532'
test "$(docker network inspect --format '{{.Internal}}' "$network")" = true
echo ISOLATION_PROFILE_PASS
