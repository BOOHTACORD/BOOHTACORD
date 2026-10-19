set -eu
cd /home/runner/actions-runner
curl -fsSL --retry 3 -o /tmp/runner.tar.gz https://github.com/actions/runner/releases/download/v2.338.0/actions-runner-linux-x64-2.338.0.tar.gz
printf '%s\n' 'af4b794c1bc41d73d40535e3fe092a39f9679cd8d965954c2aca25a05ca41d32  /tmp/runner.tar.gz' | sha256sum -c -
tar -xzf /tmp/runner.tar.gz
rm /tmp/runner.tar.gz
chown -R runner:runner /home/runner/actions-runner
cd /usr/local/lib/android/sdk
curl -fsSL --retry 3 -o /tmp/cmdline.zip https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip
printf '%s\n' 'e025545c62a8e64c7559119566a569fb1dec5f60  /tmp/cmdline.zip' | sha1sum -c -
unzip -q /tmp/cmdline.zip -d /tmp/android-cmdline
mkdir -p cmdline-tools
mv /tmp/android-cmdline/cmdline-tools cmdline-tools/19.0
rm -rf /tmp/android-cmdline /tmp/cmdline.zip
chown -R runner:runner /usr/local/lib/android/sdk
printf 'ANDROID_HOME=/usr/local/lib/android/sdk\nANDROID_SDK_ROOT=/usr/local/lib/android/sdk\n' >> /etc/environment
