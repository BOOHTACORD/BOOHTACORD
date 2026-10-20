set -eu
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends ca-certificates curl git sudo jq unzip zip xz-utils python3 python3-pip python3-venv build-essential libicu74 libkrb5-3 zlib1g libssl3t64 liblttng-ust1t64 libunwind8 docker.io docker-compose-v2 docker-buildx openjdk-17-jdk-headless clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libsecret-1-dev xvfb postgresql-client rsync iproute2 iputils-ping
id runner >/dev/null 2>&1 || useradd --create-home --uid 1001 --shell /bin/bash runner
usermod -aG docker runner
printf 'runner ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/boohtacord-runner
chmod 440 /etc/sudoers.d/boohtacord-runner
install -d -o runner -g runner /opt/hostedtoolcache /usr/local/lib/android/sdk /home/runner/actions-runner
systemctl enable --now docker
apt-get clean
rm -rf /var/lib/apt/lists/*
