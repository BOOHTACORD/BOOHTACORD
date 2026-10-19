#!/usr/bin/env bash
set -euo pipefail

printf 'docker_server_version=%s\n' "$(sudo -n docker version --format '{{.Server.Version}}')"
printf 'docker_storage_driver=%s\n' "$(sudo -n docker info --format '{{.Driver}}')"
printf 'docker_driver_status=%s\n' "$(sudo -n docker info --format '{{json .DriverStatus}}')"
if [[ -r /etc/os-release ]]; then
  source /etc/os-release
  printf 'host_os=%s %s\n' "${ID:-unknown}" "${VERSION_ID:-unknown}"
fi
if command -v apt-cache >/dev/null 2>&1; then
  apt-cache policy docker-buildx-plugin | head -n 12
fi
if sudo -n docker buildx version; then
  printf 'buildx_available=yes\n'
  sudo -n docker buildx ls
else
  printf 'buildx_available=no\n'
fi
sudo -n docker system df

mountpoint="$(sudo -n docker volume inspect --format '{{.Mountpoint}}' voice-platform_attachments-data)"
[[ "$mountpoint" == /* ]] || { echo 'Attachment volume mountpoint is invalid' >&2; exit 1; }
printf 'attachment_volume_mountpoint=%s\n' "$mountpoint"
sudo -n df -B1 --output=avail,size -- "$mountpoint" /opt/voice-platform-releases

for service in api web; do
  container="$(sudo -n docker ps --filter label=com.docker.compose.project=voice-platform --filter "label=com.docker.compose.service=$service" --format '{{.ID}}')"
  [[ "$container" =~ ^[0-9a-f]{12,64}$ ]] || { echo "Running $service container is unavailable" >&2; exit 1; }
  image="$(sudo -n docker inspect --format '{{.Config.Image}}' "$container")"
  if [[ "$image" =~ ^voice-platform-${service}:([0-9a-f]{40})$ ]]; then
    service_revision="${BASH_REMATCH[1]}"
  else
    service_revision="$(sudo -n docker inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$container")"
    [[ "$service_revision" =~ ^[0-9a-f]{40}$ ]] || { echo "Running $service revision is invalid" >&2; exit 1; }
  fi
  if [[ -n "${release_revision:-}" && "$service_revision" != "$release_revision" ]]; then
    echo 'Running API and web revisions differ' >&2
    exit 1
  fi
  release_revision="$service_revision"
  printf '%s_image_size_bytes=%s\n' "$service" "$(sudo -n docker image inspect --format '{{.Size}}' "$image")"
  printf '%s_image_id=%s\n' "$service" "$(sudo -n docker image inspect --format '{{.Id}}' "$image")"
done
printf 'deployed_revision=%s\n' "$release_revision"
