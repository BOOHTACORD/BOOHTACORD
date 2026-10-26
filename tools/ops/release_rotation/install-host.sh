#!/usr/bin/env bash
set -euo pipefail
[[ "$(id -u)" == 0 ]] || { echo 'Run this installer as root' >&2; exit 1; }
repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repository"
files=(tools/ops/release_rotation/{catalog,policy,run,test_rotation}.py tools/release/bundle/{manifest,signature}.py)
version="$(sha256sum "${files[@]}" | awk '{print $1}' | sha256sum | awk '{print $1}')"
root=/usr/local/lib/boohtacord-release-rotation
base="$root/$version"
install -d -o root -g root -m 0755 "$root" "$base"
for file in "${files[@]}"; do install -D -o root -g root -m 0644 "$file" "$base/$file"; done
(
  cd "$base"
  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tools.ops.release_rotation.test_rotation
  PYTHONDONTWRITEBYTECODE=1 python3 -m tools.ops.release_rotation.run
)
for unit in service timer; do
  install -o root -g root -m 0644 "tools/ops/release_rotation/systemd/boohtacord-release-rotation.$unit" "/etc/systemd/system/boohtacord-release-rotation.$unit"
done
ln -sfn "$version" "$root/current"
systemd-analyze verify /etc/systemd/system/boohtacord-release-rotation.{service,timer}
systemctl daemon-reload
systemctl enable --now boohtacord-release-rotation.timer
