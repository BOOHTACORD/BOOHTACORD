"""Link and execute a real C++ consumer of the Apple audio Swift package."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('This gate requires macOS and the Xcode Swift toolchain')
    root = Path(__file__).resolve().parents[3]
    package = root / 'clients/flutter/packages/flutter_webrtc/common/rnnoise'
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='apple-audio-link-', dir=output) as temporary:
        work = Path(temporary)
        source = work / 'Sources/AppleAudioLinkProbe'
        source.mkdir(parents=True)
        shutil.copyfile(Path(__file__).with_name('probe.cc'), source / 'main.cpp')
        (work / 'Package.swift').write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "AppleAudioLinkProbe", platforms: [.macOS(.v11)],
  dependencies: [.package(name: "BoohtaRnnoise", path: PACKAGE_PATH)],
  targets: [.executableTarget(name: "AppleAudioLinkProbe", dependencies: [
    .product(name: "BoohtaRnnoise", package: "BoohtaRnnoise")])],
  cxxLanguageStandard: .cxx17)
'''.replace('PACKAGE_PATH', json.dumps(str(package))))
        command = ['swift', 'run', '--package-path', str(work), 'AppleAudioLinkProbe']
        with (output / 'link-and-run.log').open('w') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
    files = [package / 'Package.swift', Path(__file__), Path(__file__).with_name('probe.cc')]
    report = {'status': 'PASS' if result.returncode == 0 else 'FAIL',
              'scope': 'Actual Swift package; strict downstream executable link and synthetic PCM only. No device/media acceptance.',
              'command': 'swift run --package-path <temporary consumer> AppleAudioLinkProbe',
              'source_sha256': {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}}
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(report['status'])
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
